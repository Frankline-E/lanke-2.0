import nodeConfig from '@repo/eslint-config/node'

// export default [...nodeConfig, { ignores: ["dist/"] }];

export default [
  ...nodeConfig,
  {
    ignores: ['dist/', 'drizzle/'],
  },
]
