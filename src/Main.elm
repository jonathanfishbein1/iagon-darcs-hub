port module Main exposing
    ( Flags
    , Model(..)
    , Msg(..)
    , buttonHoverColor
    , init
    , main
    , subscriptions
    , update
    , view
    )

import BigInt
import Browser
import ConnectWallet
import Element
import Element.Background
import Element.Border
import Element.Font
import Element.Input
import Html
import Json.Decode
import Json.Encode
import Loading
import Maybe.Extra
import Toop


font : Element.Attribute msg
font =
    Element.Font.family
        [ Element.Font.typeface "Syntha"
        ]


btcRuinModelEncoder : BTCRuinModel -> Json.Encode.Value
btcRuinModelEncoder bTCRuinModel =
    Json.Encode.object
        [ ( "btcAddress"
          , Json.Encode.string
                (case bTCRuinModel.btcAddress of
                    Just btcAddress ->
                        btcAddress

                    Nothing ->
                        ""
                )
          )
        , ( "radAmount"
          , (BigInt.toString >> Json.Encode.string)
                (case bTCRuinModel.radAmount of
                    Just radAmount ->
                        radAmount

                    Nothing ->
                        BigInt.fromInt 0
                )
          )
        ]


type alias NetworkSubdomain =
    String


type Msg
    = ConnectW ConnectWallet.Msg
    | Login
    | EnterRADAmount String
    | CantSubmit
    | Submit NetworkSubdomain
    | ReceiveSubmitAddressAndSendRAD String
    | ReceiveAmountOfRad Int
    | CheckCheckbox Bool
    | NoOp


initialBTCRuinModel : BTCRuinModel
initialBTCRuinModel =
    { btcAddress = Nothing
    , radAmount = Nothing
    , totalAmountOfRadInWallet = Nothing
    , radAmountError = Nothing
    , btcAddressError = Nothing
    , iAcknowledge = False
    , iAcknowledgeError = Nothing
    , transactionError = Nothing
    }


type alias BTCRuinModel =
    { btcAddress : Maybe String
    , radAmount : Maybe BigInt.BigInt
    , totalAmountOfRadInWallet : Maybe BigInt.BigInt
    , radAmountError : Maybe String
    , btcAddressError : Maybe String
    , iAcknowledge : Bool
    , iAcknowledgeError : Maybe String
    , transactionError : Maybe String
    }


type Model
    = WalletState String ConnectWallet.Model
    | Connected NetworkSubdomain ConnectWallet.Model BTCRuinModel
    | Submitting NetworkSubdomain ConnectWallet.Model BTCRuinModel
    | Submitted NetworkSubdomain String
    | NoAda
    | NullState


type alias Flags =
    { walletsInstalledAndEnabledStrings : List String
    , networkSubdomain : String
    }


init : Flags -> ( Model, Cmd Msg )
init { walletsInstalledAndEnabledStrings, networkSubdomain } =
    case walletsInstalledAndEnabledStrings of
        [] ->
            ( WalletState networkSubdomain ConnectWallet.NotConnectedNotAbleTo, Cmd.none )

        _ ->
            let
                walletsInstalledAndEnabled : List ConnectWallet.SupportedWallet
                walletsInstalledAndEnabled =
                    List.map ConnectWallet.decodeWallet walletsInstalledAndEnabledStrings
                        |> Maybe.Extra.values

                ( newWalletModel, newWalletCmd ) =
                    ConnectWallet.update ConnectWallet.ChooseWallet
                        (ConnectWallet.NotConnectedButWalletsInstalledAndEnabled
                            (Element.el [ font ] (Element.text "Select Wallet"))
                            walletsInstalledAndEnabled
                        )
            in
            ( WalletState networkSubdomain
                newWalletModel
            , Cmd.map ConnectW newWalletCmd
            )


type TransactionError
    = Declined
    | InputsExhausted
    | MaxCollateralInputs
    | Other String
    | None


determineTransactionError : String -> TransactionError
determineTransactionError errorString =
    if "Declined" == errorString then
        Declined

    else if "InputsExhausted" == errorString then
        InputsExhausted

    else if "MaxCollateralInputs" == errorString then
        MaxCollateralInputs

    else if String.contains "Error" errorString then
        Other errorString

    else
        None


transactionErrorMessage : TransactionError -> String
transactionErrorMessage transactionError =
    case transactionError of
        Declined ->
            ""

        InputsExhausted ->
            "Inputs exhausted, check value in wallet"

        MaxCollateralInputs ->
            "MaxCollateralInputs"

        Other error ->
            error

        None ->
            ""


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( ConnectW walletMsg, WalletState networkSubdomain walletModel ) ->
            let
                ( newWalletModel, newWalletCmd ) =
                    ConnectWallet.update walletMsg walletModel
            in
            case newWalletModel of
                ConnectWallet.ConnectionEstablished _ _ _ _ ->
                    ( Connected networkSubdomain
                        newWalletModel
                        initialBTCRuinModel
                    , getAmountOfRad ()
                    )

                _ ->
                    ( WalletState networkSubdomain newWalletModel
                    , Cmd.map ConnectW newWalletCmd
                    )

        ( Login, Connected networkSubdomain walletModel btcRuinModel ) ->
            ( Connected networkSubdomain walletModel btcRuinModel
            , Cmd.none
            )

        ( EnterRADAmount radAmountString, Connected networkSubdomain walletModel btcRuinModel ) ->
            let
                newBtcRuinModel =
                    { btcRuinModel
                        | radAmount = BigInt.fromIntString radAmountString
                    }

                newerBtcRuinModel =
                    { newBtcRuinModel
                        | radAmountError =
                            if newBtcRuinModel.radAmount == Nothing then
                                Just "no RAD input"

                            else
                                case Maybe.map2 BigInt.gt btcRuinModel.radAmount btcRuinModel.totalAmountOfRadInWallet of
                                    Just True ->
                                        Just "not enough RAD"

                                    _ ->
                                        Nothing
                    }
            in
            ( Connected networkSubdomain walletModel newerBtcRuinModel
            , Cmd.none
            )

        ( Submit networkSubdomain, Connected _ walletModel btcRuinModel ) ->
            ( Submitting networkSubdomain walletModel btcRuinModel
            , submitAddressAndSendRAD (btcRuinModelEncoder btcRuinModel)
            )

        ( ReceiveSubmitAddressAndSendRAD resultJson, Submitting networkSubdomain walletModel btcRuinModel ) ->
            let
                result =
                    Json.Decode.decodeString Json.Decode.string resultJson
            in
            case result of
                Ok r ->
                    let
                        error =
                            determineTransactionError r
                    in
                    case error of
                        Declined ->
                            ( Connected networkSubdomain walletModel btcRuinModel
                            , Cmd.none
                            )

                        InputsExhausted ->
                            let
                                newBtcRuinModel =
                                    { btcRuinModel
                                        | transactionError =
                                            Just
                                                (transactionErrorMessage InputsExhausted)
                                    }
                            in
                            ( Connected networkSubdomain walletModel newBtcRuinModel
                            , Cmd.none
                            )

                        _ ->
                            let
                                newBtcRuinModel =
                                    { btcRuinModel
                                        | transactionError = Just "Over budget"
                                    }
                            in
                            ( Connected networkSubdomain walletModel newBtcRuinModel
                            , Cmd.none
                            )

                Err e ->
                    let
                        tError =
                            determineTransactionError (Json.Decode.errorToString e)

                        newBtcRuinModel =
                            { btcRuinModel
                                | transactionError =
                                    Just
                                        (transactionErrorMessage tError)
                            }
                    in
                    ( Connected networkSubdomain walletModel newBtcRuinModel
                    , Cmd.none
                    )

        ( ReceiveAmountOfRad tAmountOfRadInWallet, Connected networkSubdomain walletModel btcRuinModel ) ->
            let
                newBtcRuinModel =
                    { btcRuinModel
                        | totalAmountOfRadInWallet = Just (BigInt.fromInt tAmountOfRadInWallet)
                    }
            in
            ( Connected networkSubdomain walletModel newBtcRuinModel, Cmd.none )

        ( CheckCheckbox value, Connected networkSubdomain walletModel btcRuinModel ) ->
            let
                newBtcRuinModel =
                    { btcRuinModel
                        | iAcknowledge = value
                        , iAcknowledgeError =
                            if value == True then
                                Nothing

                            else
                                Just "must acknowledge"
                    }
            in
            ( Connected networkSubdomain walletModel newBtcRuinModel, Cmd.none )

        ( CantSubmit, Connected networkSubdomain walletModel btcRuinModel ) ->
            let
                newerBtcRuinModel =
                    { btcRuinModel
                        | iAcknowledgeError =
                            if btcRuinModel.iAcknowledge == False then
                                Just "must acknowledge"

                            else
                                Nothing
                        , btcAddressError =
                            if btcRuinModel.btcAddress == Nothing then
                                Just "BTC address length wrong"

                            else
                                Maybe.andThen
                                    (\btcAddress ->
                                        if
                                            String.length btcAddress
                                                > 0
                                        then
                                            Nothing

                                        else
                                            Just "BTC address length wrong"
                                    )
                                    btcRuinModel.btcAddress
                        , radAmountError =
                            if btcRuinModel.radAmount == Nothing then
                                Just "no RAD input"

                            else
                                case Maybe.map2 BigInt.gt btcRuinModel.radAmount btcRuinModel.totalAmountOfRadInWallet of
                                    Just True ->
                                        Just "not enough RAD"

                                    _ ->
                                        Nothing
                    }
            in
            ( Connected networkSubdomain walletModel newerBtcRuinModel, Cmd.none )

        _ ->
            ( model, Cmd.none )


view : Element.Color -> Model -> Html.Html Msg
view fontColor model =
    Element.layout
        [ Element.Background.uncropped "radBtcRuins.jpg"
        , Element.width Element.fill
        , Element.height Element.fill
        , Element.Background.color (Element.rgb255 0 0 0)
        , font
        ]
        (case model of
            WalletState _ ws ->
                Element.el
                    [ Element.centerX
                    , Element.centerY
                    ]
                    (Element.html (Html.map ConnectW (ConnectWallet.view fontColor ws)))

            Connected networkSubdomain walletModel btcRuinModel ->
                Element.column
                    [ Element.centerX
                    , Element.centerY
                    , Element.spacing 50
                    ]
                    [ Element.Input.button
                        [ Element.centerX
                        , Element.mouseOver
                            [ Element.Border.glow buttonHoverColor
                                10
                            ]
                        , Element.Background.color (Element.rgb255 0 0 0)
                        ]
                        { onPress = Just Login
                        , label = Element.text "Login"
                        }
                    ]

            Submitting _ _ _ ->
                Element.el
                    [ Element.centerX
                    , Element.centerY
                    ]
                    (Loading.render Loading.Sonar Loading.defaultConfig Loading.On
                        |> Element.html
                    )

            Submitted networkSubdomain txHash ->
                Element.column
                    [ Element.centerX
                    , Element.centerY
                    , Element.spacing 30
                    ]
                    [ Element.el
                        [ Element.centerX
                        , Element.centerY
                        ]
                        (Element.newTabLink
                            [ Element.mouseOver
                                [ Element.Border.glow buttonHoverColor
                                    10
                                ]
                            ]
                            { url = "https://" ++ networkSubdomain ++ "cexplorer.io/tx/" ++ txHash
                            , label = Element.text txHash
                            }
                        )
                    ]

            NoAda ->
                Element.Input.button
                    []
                    { onPress =
                        Just
                            NoOp
                    , label =
                        Element.text
                            "Initialize account with some Ada"
                    }

            NullState ->
                Element.none
        )


buttonHoverColor : Element.Color
buttonHoverColor =
    Element.rgb255 3 233 244


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        WalletState _ walletModel ->
            Sub.map ConnectW (ConnectWallet.subscriptions walletModel)

        Connected _ _ _ ->
            receiveAmountOfRad ReceiveAmountOfRad

        Submitting _ _ _ ->
            receiveSubmitAddressAndSendRAD ReceiveSubmitAddressAndSendRAD

        _ ->
            Sub.none


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view =
            view (Element.rgb255 200 200 200)
        , subscriptions = subscriptions
        }


port submitAddressAndSendRAD : Json.Encode.Value -> Cmd msg


port receiveSubmitAddressAndSendRAD : (String -> msg) -> Sub msg


port getAmountOfRad : () -> Cmd msg


port receiveAmountOfRad : (Int -> msg) -> Sub msg
