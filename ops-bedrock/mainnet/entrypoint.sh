#!/bin/sh
set -exu

VERBOSITY=${GETH_VERBOSITY:-3}
GETH_DATA_DIR=/datadir
GETH_CHAINDATA_DIR="$GETH_DATA_DIR/geth/chaindata"
GETH_KEYSTORE_DIR="$GETH_DATA_DIR/keystore"
GENESIS_FILE_PATH="${GENESIS_FILE_PATH:-/genesis.json}"
GETH_SNAPSHOT_FILE_PATH="/mainnet.tar"

CHAIN_ID=789
BLOCK_SIGNER_PRIVATE_KEY="496941b9bc92dcf6c01cc587e79a9cf6a0374d3c2c92599bbab57410652af51b"
BLOCK_SIGNER_ADDRESS="0xcb9474b271d50b3677cd852ce4fd3ca034bc010f"
RPC_PORT="${RPC_PORT:-8545}"
WS_PORT="${WS_PORT:-8546}"

if [[  -f "$GETH_SNAPSHOT_FILE_PATH" ]] && [[ ! -d "$GETH_KEYSTORE_DIR" ]]; then
echo "$GETH_SNAPSHOT_FILE_PATH snapshot available, processing..."
tar xvf "$GETH_SNAPSHOT_FILE_PATH" -C ./ ;
fi

if [ ! -d "$GETH_KEYSTORE_DIR" ]; then
	echo "$GETH_KEYSTORE_DIR missing, running account import"
	echo -n "pwd" > "$GETH_DATA_DIR"/password
	echo -n "$BLOCK_SIGNER_PRIVATE_KEY" | sed 's/0x//' > "$GETH_DATA_DIR"/block-signer-key
	geth account import \
		--datadir="$GETH_DATA_DIR" \
		--password="$GETH_DATA_DIR"/password \
		"$GETH_DATA_DIR"/block-signer-key
else
	echo "$GETH_KEYSTORE_DIR exists."
fi

if [ ! -d "$GETH_CHAINDATA_DIR" ]; then
	echo "$GETH_CHAINDATA_DIR missing, running init"
	echo "Initializing genesis."
	geth --verbosity="$VERBOSITY" init \
		--datadir="$GETH_DATA_DIR" \
		"$GENESIS_FILE_PATH"
else
	echo "$GETH_CHAINDATA_DIR exists."
fi

# Warning: Archive mode is required, otherwise old trie nodes will be
# pruned within minutes of starting the mainnet.

exec geth \
	--datadir="$GETH_DATA_DIR" \
	--verbosity="$VERBOSITY" \
	--http \
	--http.corsdomain="*" \
	--http.vhosts="*" \
	--http.addr=0.0.0.0 \
	--http.port="$RPC_PORT" \
	--http.api=web3,debug,eth,txpool,net,engine \
	--ws \
	--ws.addr=0.0.0.0 \
	--ws.port="$WS_PORT" \
	--ws.origins="*" \
	--ws.api=debug,eth,txpool,net,engine \
	--syncmode=full \
	--nodiscover \
	--maxpeers=1 \
	--networkid=$CHAIN_ID \
	--unlock=$BLOCK_SIGNER_ADDRESS \
	--mine \
	--miner.etherbase=$BLOCK_SIGNER_ADDRESS \
	--password="$GETH_DATA_DIR"/password \
	--allow-insecure-unlock \
	--authrpc.addr="0.0.0.0" \
	--authrpc.port="8551" \
	--authrpc.vhosts="*" \
	--gcmode=archive \
	--metrics \
	--metrics.addr=0.0.0.0 \
	--metrics.port=6060 \
	"$@"
