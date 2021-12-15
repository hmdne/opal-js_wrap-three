import { nodeResolve } from '@rollup/plugin-node-resolve';
import { babel } from '@rollup/plugin-babel';
import commonjs from '@rollup/plugin-commonjs';

export default {
  input: 'src/three.mjs',
  output: {
    dir: 'lib-opal/js_wrap/three/',
    format: 'iife'
  },
  plugins: [
    nodeResolve(),
    commonjs(),
    babel({
      "babelHelpers": "runtime",
      "presets": ["@babel/preset-env"],
      "compact" : false,
      "targets": { "chrome": 38 },
      "plugins": [
        "@babel/plugin-transform-runtime"
      ]
    })
  ]
};

