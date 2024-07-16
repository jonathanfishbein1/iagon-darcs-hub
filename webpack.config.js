import path from 'path'
import webpack from 'webpack'
import HtmlWebPackPlugin from "html-webpack-plugin"
const __dirname = path.resolve()
  , network = process.env.NETWORK || 'Mainnet'
  , environment = process.env.NODE_ENV || 'production'

console.log(network)
export default (_env, args) => ({
  mode: environment,
  entry: './index.ts',
  output: {
    path: path.resolve(__dirname, 'dist/'),
    publicPath: '/',
    filename: '[contenthash].js',
    clean: true,
    assetModuleFilename: '[name][ext]'
  },
  target: 'web',
  resolve: {
    extensions: ['.tsx', '.ts', '.js'],
  },
  module: {
    rules: [
      {
        test: /\.(png|jpg|gif|svg|eot|ttf|woff|webp|eps|mp4|jpeg|otf)$/,
        type: 'asset/resource'
      },
      {
        test: /\.html$/,
        use: [
          {
            loader: "html-loader",
          }
        ]
      },
      {
        test: /\.tsx?$/,
        use: [
          {
            loader: 'ts-loader',
            options: {
              transpileOnly: true
            }
          },
        ],
      },
      {
        test: /\.elm$/,
        exclude: /elm-stuff/,
        use: {
          loader: "elm-webpack-loader",
        }
      },
      {
        test: /\.txt/,
        type: 'asset/source',
      }
    ]
  },
  optimization: {
  },
  plugins: [new HtmlWebPackPlugin({
    title: 'index',
    filename: `index.html`,
    template: `./index.html`,
  }),
  new webpack.DefinePlugin({
    network: JSON.stringify(network)
  }),
  new webpack.ProvidePlugin({ Buffer: ['buffer', 'Buffer'] })
  ]
  , experiments: {
    asyncWebAssembly: true,
    outputModule: true,
    topLevelAwait: true,
    layers: true
  }
})
