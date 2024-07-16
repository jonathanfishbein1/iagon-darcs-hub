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
import Html.Attributes
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


type alias NetworkSubdomain =
    String


type Msg
    = ConnectW ConnectWallet.Msg
    | Login
    | ReceiveLogin Bool
    | ShowRepo
    | NoOp


type Model
    = WalletState String ConnectWallet.Model
    | Connected NetworkSubdomain ConnectWallet.Model (List String)
    | LoggedIn NetworkSubdomain ConnectWallet.Model (List String)
    | RepoDetail NetworkSubdomain ConnectWallet.Model (List String)
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
                        [ "darcshub"
                        ]
                    , Cmd.none
                    )

                _ ->
                    ( WalletState networkSubdomain newWalletModel
                    , Cmd.map ConnectW newWalletCmd
                    )

        ( Login, Connected networkSubdomain walletModel btcRuinModel ) ->
            ( Connected networkSubdomain walletModel btcRuinModel
            , login ()
            )

        ( ShowRepo, LoggedIn networkSubdomain walletModel btcRuinModel ) ->
            ( RepoDetail networkSubdomain walletModel btcRuinModel
            , Cmd.none
            )

        ( ReceiveLogin loggedIn, Connected networkSubdomain walletModel btcRuinModel ) ->
            ( LoggedIn networkSubdomain walletModel btcRuinModel
            , Cmd.none
            )

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

            LoggedIn networkSubdomain walletModel btcRuinModel ->
                Element.column []
                    (List.map
                        (\repo ->
                            Element.Input.button []
                                { onPress = Just ShowRepo
                                , label = Element.text repo
                                }
                        )
                        [ "darcshub"
                        ]
                    )

            RepoDetail networkSubdomain walletModel btcRuinModel ->
                Element.column
                    [ Element.centerX
                    , Element.centerY
                    , Element.spacing 50
                    ]
                    [ Element.html
                        (Html.iframe
                            [ Html.Attributes.sandbox "allow-popups allow-forms allow-scripts allow-same-origin"
                            , Html.Attributes.src
                                "https://sparkling-mud-0507.iagon.io/"
                            , Html.Attributes.style "width" "100%"
                            , Html.Attributes.style "height" "100%"
                            , Html.Attributes.attribute "frameBorder" "0"
                            ]
                            []
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
            receiveLogin
                ReceiveLogin

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


port login : () -> Cmd msg


port receiveLogin : (Bool -> msg) -> Sub msg
