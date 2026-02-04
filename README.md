# Bitcoin Node Script

Repository นี้รวบรวม Script สำหรับติดตั้ง Bitcoin Full Node เพื่อให้ง่ายในการเป็นเจ้าของโหนดตัวเองและในแต่ละ Script มีการตั้งค่าไว้พร้อมใช้งานได้เลย ง่ายสำหรับคนที่พึ่งเริ่มต้น

## Script

*   **Firewall (`ufw`)**: ตั้งค่าไฟร์วอลล์พื้นฐานสำหรับ Bitcoin Node โดยอนุญาตเฉพาะพอร์ตที่จำเป็น
*   **Tor**: กำหนดค่า Tor เพื่อเพิ่มความเป็นส่วนตัว ทำให้ Bitcoin node และบริการต่างๆ ของคุณทำงานเป็น Hidden service ได้
*   **I2P**: กำหนดค่า i2pd สำหรับการเชื่อมต่อเครือข่าย I2P สำหรับ Bitcoin node
*   **Bitcoin Core (`bitcoind`)**: ติดตั้งและกำหนดค่าพื้นฐาน Bitcoin Core v30.2
*   **Electrum Rust Server (`electrs`)**: ติดตั้งเซิร์ฟเวอร์ Electrum ที่รวดเร็วและมีประสิทธิภาพสำหรับเชื่อมต่อกับ Wallet
*   **BTC RPC Explorer**: มีหน้าเว็บ Block Explorer สำหรับ Bitcoin node ของคุณ
*   **Status Dashboard (`check_status.sh`)**: สคริปต์แบบ all-in-one เพื่อตรวจสอบสถานะของบริการทั้งหมดและ Bitcoin node ของคุณ
*   **Tor Hidden Services (`show_hidden_services.sh`)**: แสดง .onion addresses สำหรับบริการ Tor hidden service ที่ตั้งค่าไว้ 

## Prerequisites

* OS: Debian / Ubuntu (แนะนำการติดตั้งใหม่)
* User: สิทธิ์ sudo สำหรับจัดการระบบ
* Network: การเชื่อมต่ออินเทอร์เน็ตที่เสถียร
* Skill: พื้นฐานการใช้ Linux Command Line (Terminal)

## ติดตั้งและใช้งาน

แนะนำให้รันสคริปต์ตามลำดับด้านล่าง แต่ละสคริปต์ถูกออกแบบมาเพื่อติดตั้งและกำหนดค่าไว้พร้อมใช้งานแล้ว

1.  **Clone the Repository:**

    ```bash
    git clone https://github.com/notoshi404/script-setup-bitcoin-node.git
    ```

2.  **ติดตั้ง Firewall (`setup_fw.sh`)**
    สคริปต์นี้จะตั้งค่า `ufw` (Uncomplicated Firewall) อนุญาตพอร์ตที่จำเป็นสำหรับบริการทั้งหมด SSH, Bitcoin P2P, RPC, Electrs, Tor และ I2Pd

    ```bash
    sudo ./setup_fw.sh
    ```

3.  **ติดตั้ง Tor (`setup_tor.sh`)**
    สคริปต์นี้จะติดตั้งและกำหนดค่า Tor โดยตั้งค่า Hidden service ต่างๆ สำหรับ Bitcoin RPC, Electrs, BTC RPC Explorer และ Mempool สามารถกำหนดค่าเพิ่มเติมได้ในภายหลัง

    ```bash
    sudo ./setup_tor.sh
    ```

4.  **ติดตั้ง I2Pd (`setup_i2pd.sh`)**
    สคริปต์นี้จะติดตั้งและกำหนดค่า I2P Daemon เพื่อเปิดใช้งาน SAM interface สำหรับให้ Bitcoin Core ใช้

    ```bash
    sudo ./setup_i2pd.sh
    ```

5.  **ติดตั้ง Bitcoin Core v30.2 (`setup_bitcoind.sh`)**
    สคริปต์นี้จะดาวน์โหลด, ตรวจสอบ, ติดตั้ง `bitcoind` นอกจากนี้ยังตั้งค่า `systemd service` และกำหนดค่าไฟล์ `bitcoin.conf` ไว้พร้อมใช้งาน

    ```bash
    sudo ./setup_bitcoind.sh
    ```

    *ในสคริปต์นี้ไม่ได้กำหนดค่า `rpcauth` ไว้อาจต้องกำหนดค่าเพิ่มเติมภายหลัง*

6.  **ติดตั้ง Electrs (`setup_electrs.sh`)**
    สคริปต์นี้จะติดตั้ง Rust, โคลน repository ของ `electrs`, build เซิร์ฟเวอร์ และตั้งค่า `systemd service` และไฟล์กำหนดค่า (`electrs.toml`) เพื่อเชื่อมต่อกับ `bitcoind`

    ```bash
    sudo ./setup_electrs.sh
    ```

7.  **ติดตั้ง BTC RPC Explorer (`setup_btc_rpc_explorer.sh`)**
    สคริปต์นี้จะติดตั้ง Node.js ผ่าน NVM, โคลน BTC RPC Explorer, ติดตั้ง dependencies, กำหนดค่า environment variables และตั้งค่า `systemd service`

    ```bash
    ./setup_btc_rpc_explorer.sh
    ```

## ตรวจสอบและการจัดการ

*   **ตรวจสอบสถานะ Node (`check_status.sh`)**:
    รันสคริปต์นี้เพื่อดูภาพรวมสถานะของระบบ, สถานะบริการ, ความคืบหน้าในการซิงค์ Bitcoin และข้อมูลเครือข่าย

    ```bash
    ./check_status.sh
    ```

*   **แสดง Tor Hidden Services (`show_hidden_services.sh`)**:
    แสดงที่อยู่ `.onion` ของ Tor hidden service ทั้งหมดที่คุณกำหนดค่าไว้ คุณจะต้องใช้ `sudo` สำหรับคำสั่งนี้

    ```bash
    sudo ./show_hidden_services.sh
    ```

## การเข้าถึงบริการ

เมื่อตั้งค่าและรันบริการทั้งหมดแล้ว คุณสามารถเข้าถึงได้ดังนี้:

*   **Bitcoin RPC**: `YOUR_IP:8332` (หรือผ่าน Tor Hidden Service)
*   **Electrs**: `YOUR_IP:50001` (TCP) หรือ `YOUR_IP:50002` (SSL) (หรือผ่าน Tor Hidden Service)
*   **BTC RPC Explorer**: `http://YOUR_IP:3002` (แทนที่ `YOUR_IP` ด้วย IP ของเครื่องคุณ เช่น `http://192.168.1.100:3002`) และยังสามารถเข้าถึงผ่าน Tor Hidden Service ได้ด้วย
*   **i2pd WebConsole**: `http://YOUR_IP:7070`

## การแก้ไขปัญหา

*   **Logs**:
    *   `bitcoind`: `tail -f ~/.bitcoin/debug.log`
    *   `electrs`: `sudo journalctl -u electrs -f`
    *   `tor`: `sudo journalctl -u tor -f`
    *   `i2pd`: `sudo journalctl -u i2pd -f`
    *   `btcrpcexplorer`: `sudo journalctl -u btcrpcexplorer -f`

*   **Systemd Status**:
    หากต้องการตรวจสอบสถานะของบริการใดๆ ให้ใช้ `sudo systemctl status <service_name>` เช่น `sudo systemctl status bitcoind`
