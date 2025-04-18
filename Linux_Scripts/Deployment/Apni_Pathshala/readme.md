### Instructions to deploy Apni Pathshala on a new machine
- Login to the machine via GUI
- Open terminal
- switch to init 3
```bash
sudo init 3
```
- Login to the terminal as standard user with sudo access or root user
- Run the following command to deploy Apni Pathshala
```bash
curl -fsSL https://link.scogo.in/apni-pathshala | sudo bash
```
- After the script is finished, switch to init 5
```bash
sudo init 5
```

