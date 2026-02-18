
const path = require('node:path');

module.exports = {
  target: 'node', //  Builds for a Node.js runtime (not browser) For Node.js apps using Express
  entry: './index.js', // Starting file
  output: {  // Compiled output file
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/, // Skips bundling dependencies like Express and other node_modules
        use: { // Transpiles modern JS to ES2015
          loader: 'esbuild-loader',
          options: { target: 'es2015' }
        }
      }
    ]
  }
};

