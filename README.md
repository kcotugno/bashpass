# Bashpass
Powerful password management from the command line

# Installation
You can easily setup Bashpass to be runable from any console.
```
git clone https://github.com/kcotugno/bashpass.git
cd bashpass
sudo chmod 755 bashpass.sh
sudo ln -s /full/path/to/bashpass/bashpass.sh /usr/local/bin/bashpass
```

# Usage
#### Commands
+ [KEY] Retreive a password with the given key.
+ -a [KEY] Add a password with the given key.
+ -d [KEY] Remove the password with the given key.
+ -l List all keys.
+ -c [KEY] [VALUE] Set configuration options.
 + 'key' A gpg key fingerprint so your're not prompted on every encryption.

# Mac OS X
Bashpass should run on Mac OS X.

# TODO
1. Copy to clipboard from command line.
2. Password generation.
