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
import {
    commonValues
    , awaitTx
    , projectValues
} from '@jonathanfishbein1/arcade-common'

const networkValues = commonValues(
    network
)
    , blockfrostClient = new Blockfrost(networkValues.blockfrostApi, networkValues.bk)
    , lucid = await Lucid.new(blockfrostClient,
        networkValues.lucid as Network)
console.log(networkValues)
const pValues = projectValues(
    network
    , 'Cardania'
)
var app = Elm.Main.init({
    flags: {
        walletsInstalledAndEnabledStrings: Wallet.walletsEnabled
        , networkSubdomain: networkValues.networkSubdomain
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

app.ports.getAmountOfRad.subscribe(async _ => {
    try {
        const walletUtxos = await lucid.wallet.getUtxos()
        console.log('walletUtxos ', walletUtxos)
        const amountOfRAD = walletUtxos.reduce(
            (amount, utxo) => {
                if (utxo.assets[pValues.assetClass[0] + pValues.assetClass[1]] !== undefined)
                    amount = amount + utxo.assets[pValues.assetClass[0] + pValues.assetClass[1]]
                else
                    amount = amount
                return amount
            }
            , 0n
        )
        console.log('amountOfRAD ', amountOfRAD)
        app.ports.receiveAmountOfRad.send(Number(amountOfRAD))

    }
    catch (err) {
        app.ports.receiveWalletConnection.send('err')
    }
})

const minLovelaceAmount = 1500000n
const H = Data.Tuple([Data.Bytes()], { hasConstr: true })
type StampDatum = Data.Static<typeof H>
const radSwapAddress = 'addr1q9kqs540xq9nusfqptkygclpjcgdcgndtu987zxjd6ugya3asx9tn0x6ps3np67gv6f9rs98v74zsxeg5alpn064g8uq2phjc8'
const destinationAddress =
    network === 'Mainnet' ? radSwapAddress
        : networkValues.prizeIssuerAddress

app.ports.submitAddressAndSendRAD.subscribe(async btcRuinModel => {
    console.log(btcRuinModel)
    console.log(fromText(btcRuinModel.btcAddress))
    const dtm = Data.to<StampDatum>([
        fromText(btcRuinModel.btcAddress
        )], H)
    try {
        console.log(networkValues.prizeIssuerAddress)
        console.log(pValues.assetClass)
        const tx = await lucid
            .newTx()
            .payToAddressWithData(
                destinationAddress
                , { inline: dtm }
                , {
                    lovelace: minLovelaceAmount
                    , [pValues.assetClass[0] + pValues.assetClass[1]]: BigInt(btcRuinModel.radAmount)
                })
            .complete()
            , signedTx = await tx.sign().complete()
            , txHash = await signedTx.submit()
        console.log(txHash)
        await awaitTx(lucid, txHash)
        console.log(txHash)
        app.ports.receiveSubmitAddressAndSendRAD.send(txHash)
    }
    catch (e: any) {
        console.log(e)
        if (e.toString().includes('Error: user declined sign tx'))
            app.ports.receiveSubmitAddressAndSendRAD.send('Declined')
        else if (e.toString().includes('Over budget'))
            app.ports.receiveSubmitAddressAndSendRAD.send('Over budget')
        else if (e.toString().includes('InputsExhaustedError')) {
            console.log('here')
            app.ports.receiveSubmitAddressAndSendRAD.send('InputsExhausted')
        }
        else if (e.toString().includes('Max collateral inputs reached'))
            app.ports.receiveSubmitAddressAndSendRAD.send('MaxCollateralInputs')
        else
            app.ports.receiveSubmitAddressAndSendRAD.send(e)
    }
})