<h1>OpenVPN Server SETUP</h1>

Como configurar um servidor de OpenVPN

---

<h2>Índice</h2>

- [🔐 Instalando a OpenVPN](#-instalando-a-openvpn)
- [🏗️ Estabelecendo uma PKI](#️-estabelecendo-uma-pki)
- [🔑 Geração de chaves e certificados](#-geração-de-chaves-e-certificados)
- [📝 Parâmetros de Diffie Hellman](#-parâmetros-de-diffie-hellman)
- [🔗 Configuração de rede](#-configuração-de-rede)
- [🔥 Firewall](#-firewall)
- [⚙️ Configurações do servidor OpenVPN](#️-configurações-do-servidor-openvpn)
- [🖥️ Configuração dos clientes](#️-configuração-dos-clientes)

---

## 🔐 Instalando a OpenVPN

Os passos são para distros Debian ou Ubuntu. Para outras distros, veja a [wiki da comunidade da openvpn](https://community.openvpn.net/).

Faça login como sudo e importe a chave pública:

```sh
sudo su
curl -fsSL https://swupdate.openvpn.net/repos/repo-public.gpg | tee /etc/apt/keyrings/openvpn-repo-public.asc
```

Agora crie um fragmento de sources.list com o mirror de pacotes OpenVPN

```sh
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/openvpn-repo-public.asc] https://build.openvpn.net/debian/openvpn/stable $(lsb_release -cs) main" > /etc/apt/sources.list.d/openvpn-aptrepo.list
```

Atualize a lista de pacotes e instale a openvpn:

```sh
apt-get update && apt-get install openvpn
```

Saia do modo sudo para os próximos passos.

## 🏗️ Estabelecendo uma PKI

O primeiro passo para configurar o servidor de OpenVPN é estabelecer uma **infraestrutura de chave pública** (*public key infrastructure* - PKI), que consiste de:

- Um certificado separado (chave pública) e uma chave privada para o servidor e para cada cliente.
- Um certificado de autoridade (CA) mestre e uma chave que é utilizada para assinar cada certificado do servidor e dos clientes.

Para criar a PKI, vamos utilizar a ferramenta [Easy RSA](https://github.com/OpenVPN/easy-rsa).

1. Baixe e descompacte o tarball da ferramenta:

```sh
wget https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.4/EasyRSA-3.2.4.tgz && \
tar -xvf EasyRSA-3.2.4.tgz
```

2. Edite as configurações necessárias da PKI criando um arquivo `vars` com base no `vars.example`:

```sh
cd EasyRSA-3.2.4/
cp vars.example vars
```

3. Inicialize uma nova PKI e construa um par de chaves e certificado para o servidor CA:

```sh
./easyrsa init-pki
./easyrsa build-ca nopass
```

## 🔑 Geração de chaves e certificados

4. Crie a chave e certificado para o servidor

```sh
./easyrsa build-server-full <nome-do-servidor> nopass
```

5. Crie os certificados e chaves para cada um dos clientes:

```sh
./easyrsa build-client-full <nome-do-cliente-1> nopass
./easyrsa build-client-full <nome-do-cliente-2> nopass
./easyrsa build-client-full <nome-do-cliente-3> nopass
...
```

## 📝 Parâmetros de Diffie Hellman

Os parâmetros de Diffie-Hellman são usados para estabelecer um segredo compartilhado entre duas partes (por exemplo, um cliente e um servidor) através de um canal de comunicação inseguro. Esse segredo compartilhado pode então ser usado para criptografar as comunicações futuras, garantindo que somente as duas partes possam ler as mensagens.

A segurança do Diffie-Hellman reside na dificuldade de calcular as chaves privadas a partir das chaves públicas e dos parâmetros públicos. Isso permite que as duas partes estabeleçam uma chave de criptografia segura sem nunca transmiti-la diretamente, protegendo a comunicação contra interceptadores.

6. Gere os parâmetros de Diffie Hellman:

```sh
./easy-rsa gen-dh
```

## 🔗 Configuração de rede

Habilite o IP Forwarding:

```sh
sudo vim /etc/sysctl.conf
```

E garante que esta linha esteja descomentada:

```conf
net.ipv4.ip_forward=1
```

Salve o arquivo e aplique a mudança:

```sh
sudo sysctl -p
```

## 🔥 Firewall

Instale o ufw:

```sh
sudo apt install ufw -y
```

Precisamos saber qual é a sua interface de rede principal (geralmente eth0 ou ens3). Descubra com o comando:

```sh
ip route | grep default
```

A saída mostrará o nome da interface depois de "dev". Ex: `default via ... dev eth0 ...`

Agora, edite o arquivo de regras do UFW:

```sh
sudo nano /etc/ufw/before.rules
```

Adicione o seguinte bloco de código no topo do arquivo, antes da linha *filter:

```conf
#
# Regras para NAT do OpenVPN
#
*nat
:POSTROUTING ACCEPT [0:0]
# Permite o tráfego da VPN (10.8.0.0/24) para a internet através da sua interface principal
-A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
COMMIT
```

Agora, permita o tráfego OpenVPN e SSH através do firewall:

```sh
# Permite conexões na porta do OpenVPN
sudo ufw allow 1194/udp

# IMPORTANTE: Garanta que você não será bloqueado do seu próprio servidor!
sudo ufw allow OpenSSH
sudo ufw allow 22

# Ative o firewall
sudo ufw enable
```

Garanta que o tráfego de encaminhamento seja possibilitado pelo UFW:

```sh
sudo nano /etc/default/ufw
```

Procure pela linha DEFAULT_FORWARD_POLICY. Ela deve estar configurada como "ACCEPT"

```conf
DEFAULT_FORWARD_POLICY="ACCEPT"
```

Se estiver como "DROP", troque para "ACCEPT", salve o arquivo e reinicie o UFW com sudo ufw reload.

```sh
sudo ufw reload
```

## ⚙️ Configurações do servidor OpenVPN

Copie os arquivos do servidor para o diretório do OpenVPN:

```sh
sudo cp pki/ca.crt /etc/openvpn/
sudo cp pki/issued/<nome-do-servidor>.crt /etc/openvpn/
sudo cp pki/private/<nome-do-servidor>.key /etc/openvpn/
sudo cp pki/dh.pem /etc/openvpn/
```

Edite o arquivo de configurações do servidor:

```sh
sudo nano /etc/openvpn/server.conf
```

e cole estas configurações:

```conf
# Porta e Protocolo
port 1194
proto udp
dev tun

# Certificados e Chaves (usando os nomes que você gerou)
ca ca.crt
cert <nome-do-servidor>.crt
key <nome-do-servidor>.key
dh dh.pem

# Configurações de Rede do Servidor VPN
# Isso define a sub-rede virtual da VPN. 
# O servidor será 10.8.0.1 e os clientes receberão IPs dessa faixa.
server 10.8.0.0 255.255.255.0

# Manter um registro dos IPs dos clientes para que eles recebam sempre o mesmo IP
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# Forçar todo o tráfego dos clientes a passar pela VPN
push "redirect-gateway def1 bypass-dhcp"

# Usar os servidores DNS do Google para os clientes conectados
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# Manter a conexão ativa
keepalive 10 120

# Criptografia (padrões modernos e seguros)
cipher AES-256-GCM
auth SHA256

# Aumentar a segurança descartando privilégios após iniciar
user nobody
group nogroup

# Preservar chaves e o túnel em caso de reinício
persist-key
persist-tun

# Arquivos de log
status /var/log/openvpn/openvpn-status.log
log-append  /var/log/openvpn/openvpn.log

# Nível de detalhe do log (3 é um bom padrão)
verb 3

# Tamanho máximo de trasmissão de unidades(MTU) - TCP
tun-mtu 1450
# Tamanho máximo de transmissão de segmentos (MSS) - UDP
mssfix 1410
```

Agora habilite e inicie o serviço OpenVPN:

```sh
# Iniciar o serviço
sudo systemctl start openvpn@server

# Habilitar para que inicie junto com o sistema
sudo systemctl enable openvpn@server

# Verificar o status para ver se há erros
sudo systemctl status openvpn@server
```

## 🖥️ Configuração dos clientes

Edite o arquivo `base.conf` deste repositório e substitua o nome `SEU_IP_PUBLICO_AQUI` pelo IP público do seu servidor de OpenVPN

Agora, para cada cliente, gere o arquivo de configurações através do script `generate_client_config.sh` através da linha de comando da seguinte forma:

```sh
./generate_client_config.sh <nome-do-cliente-1>
```

Agora é só distribuir os arquivos de configuração para seus clientes e instruí-los a instalar o openvpn e iniciar a vpn com o arquivo de configuração. Exemplo:

```sh
# Para sistemas baseados em Debian/Ubuntu
sudo apt update && sudo apt install openvpn
sudo openvpn --config nome_do_arquivo.ovpn
```

```sh
# Para sistemas baseados em Fedora/CentOS
sudo dnf install openvpn
sudo openvpn --config nome_do_arquivo.ovpn
```

```sh
# Para sistemas baseados em MacOS
brew install openvpn
sudo openvpn --config nome_do_arquivo.ovpn
```

Ou então, através de um [cliente com interface gráfica](https://openvpn.net/client/)
