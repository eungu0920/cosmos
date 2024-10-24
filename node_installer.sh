#!/bin/bash

echo "set vars..."
read -p "Enter WALLET name:" WALLET
echo 'export WALLET='$WALLET
read -p "Enter your MONIKER:" MONIKER
echo 'export MONIKER='$MONIKER

echo "export WALLET="$WALLET"" >> $HOME/.bash_profile
echo "export MONIKER="$MONIKER"" >> $HOME/.bash_profile
echo "export CHAIN_ID="graytendermint-chain-11"" >> $HOME/.bash_profile
source $HOME/.bash_profile

echo "1. Updating packages..." && sleep 1
sudo apt-get update

echo "2. Installing dependencies..." && sleep 1
sudo apt-get install curl git jq wget build-essential -y

echo "3. Install go..."
cd $HOME
VERSION="1.22.2"
wget "https://golang.org/dl/go$VERSION.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VERSION.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1

echo "4. Installing binary..." && sleep 1
cd $HOME
sudo rm -rf cosmos-sdk
wget "https://github.com/cosmos/cosmos-sdk"
cd cosmos-sdk
git checkout v0.50.10
make install
echo $(simd version) && sleep 1

echo "5. Configuring and init app..." && sleep 1
simd config node tcp://localhost:26657
simd config keyring-backend test
simd config chain-id $CHAIN_ID
simd init $MONIKER --chain-id $CHAIN_ID
sleep 1
echo done

echo "6. Downloading genesis..." && sleep 1
wget -O $HOME/.simapp/config/genesis.json https://github.com/eungu0920....
sleep 1
echo done

echo "7. Adding seeds, peers" && sleep 1
SEEDS=""
PEERS=""
sed -i -e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*seeds *=.*/seeds = \"$SEEDS\"/}" \
-e "/^\[p2p\]/,/^\[/{s/^[[:space:]]*persistent_peers *=.*/persistent_peers = \"$PEERS\"/}" \
$HOME/.simapp/config/config.toml

sed -i 's/timeout_commit = "10s"/timeout_commit = "800ms"/' $HOME/.simapp/config/config.toml
echo "timeout_commit changed 10s to 800ms" && sleep 1
echo done

echo "8. Creating service file..." && sleep 1
sudo tee /etc/systemd/system/simd.service > /dev/null <<EOF
[Unit]
Description=Gray Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which simd) start --home $HOME/.simapp
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "9. Starting Node..." && sleep 1
sudo systemctl daemon-reload
sudo systemctl enable simd
sudo systemctl restart simd && sudo journalctl -u simd -f -o cat