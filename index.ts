import {
    Network
    , Lucid
    , Blockfrost
    , Data
    , fromText
} from 'lucid-cardano'
import * as Wallet from '../connect-cardano-wallet-elm/wallet'
var { Elm } = require('./src/Main.elm')

declare const network

const blockfrostClient = new Blockfrost(
    'https://cardano-preview.blockfrost.io/api/v0'
    , 'previewtmnlb9Ant5w6IVCSk0FKytMbYYjygteB'
)
    , lucid = await Lucid.new(
        blockfrostClient,
        'Preview' as Network
    )

var app = Elm.Main.init({
    flags: {
        walletsInstalledAndEnabledStrings: Wallet.walletsEnabled
        , networkSubdomain: 'preview.'
    },
    node: document.getElementById("elm-node")
})

app.ports.connectWallet.subscribe(async supportedWallet => {
    try {
        const wallet = await Wallet.getWalletApi(supportedWallet!) as any
        lucid.selectWallet(wallet)
        app.ports.receiveWalletConnection.send(supportedWallet)
    }
    catch (err) {
        app.ports.receiveWalletConnection.send('err')
    }
})

app.ports.login.subscribe(async () => {
    try {
        console.log('in login')
        const
            address = await lucid.wallet.address(),
            payload = fromText('darcs hub login')
        const message =
            await lucid
                .newMessage(
                    address
                    , payload
                )

        const signedMessage = await message.sign()



        const hasSigned =
            lucid
                .verifyMessage(
                    address
                    , payload
                    , signedMessage
                    ,
                )
        console.log('hasSigned ', hasSigned)
        console.log('app.ports ', app.ports)
        app.ports.receiveLogin.send(hasSigned)
    }
    catch (err) {
        console.log('err ', err)
        app.ports.receiveLogin.send(false)
    }
})