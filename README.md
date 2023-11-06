### Mantle LSP L2

L2 token contract for Mantle Liquid Staking


### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Dry run

```shell
$ source .env
$ forge script script/METHL2.s.sol --vv --rpc-url ${RPC_URL}
```

### Deploy

```shell
$ source .env
$ forge script script/METHL2.s.sol -vv --rpc-url ${RPC_URL} --broadcast
```
