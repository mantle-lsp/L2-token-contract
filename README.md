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

### Deploy DryRun

```shell
$ source .env
$ forge script script/METHL2.s.sol --vv --rpc-url ${RPC_URL}
```

### Deploy

```shell
$ source .env
$ forge script script/METHL2.s.sol -vv --rpc-url ${RPC_URL} --broadcast
```

### Upgrade DryRun

```shell
$ source .env
$ forge script script/Upgrade.s.sol:Upgrade -vv --rpc-url ${RPC_URL} -s "upgrade(string memory, bool)" METHL2 false
```

### Deploy

```shell
$ source .env
$ forge script script/Upgrade.s.sol:Upgrade -vv --rpc-url ${RPC_URL} -s "upgrade(string memory, bool)" METHL2 false --broadcast
```
