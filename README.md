# Reality Guard

A utility to block connections to Reality from non-target countries. It protects against background noise that constantly triggers TLS handshakes with the `dest` server, wasting bandwidth and increasing CPU load.

It runs on `iptables` and `ipset`, fetching IP addresses for specific countries from ip2location.com.
The database can become outdated, so please rerun the script at least once every 3 months to update the lists.

## Usage

1. **Grant execution permissions:**
   ```bash
   chmod +x reality-guard.zsh
   ```
2. **Run the script**
    ```bash
    sudo ./reality-guard.zsh
    ```

Works only on Debian or Ubuntu.
