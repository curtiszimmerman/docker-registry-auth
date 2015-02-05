#!/bin/bash

# gather user data
# https://github.com/curtiszimmerman/docker-registry-auth

newUserNames=();
newUserKeys=();

function addUser() {
    user=$1
    key=$2
    echo -n "Adding user ${user}..."
cat > "tmp/${user}.pub" << EOKEY
${key}
EOKEY
    newUserCommands="RUN useradd -m ${user}\nRUN mkdir -p /home/${user}/.ssh/\nCOPY tmp/${user}.pub /home/${user}/.ssh/${user}.pub\nRUN cat /home/${user}/.ssh/${user}.pub >> /home/${user}/.ssh/authorized_keys\n#%NEWUSERS%"
    sed -ri "N; s@#%NEWUSERS%@${newUserCommands}@" tmp/Dockerfile.tmp
    echo "done."
}

function getUser() {
    read -p "Username: " newUser
    read -p "SSH Public Key: " newKey
    if [ -z "${newUser}" ]; then
        echo -e "\nUsername empty!\n"
        break
    fi
    if [ -z "${newKey}" ]; then
        echo -e "\nPublic key empty!\n"
        break
    fi
    newUserNames=("${newUserNames[@]}" "${newUser}")
    newUserKeys=("${newUserKeys[@]}" "${newKey}")
}

function setPort() {
    read -p "What port does the docker-registry container listen on? " regPort
    if [ ${regPort} -lt 1 ] || [ ${regPort} -gt 65535 ]; then
        echo "Invalid port! Using default of 5000"
    fi
    read -p "What port should the authentication container listen on? " authPort
    if [ ${authPort} -lt 1 ] || [ ${authPort} -gt 65535 ]; then
        echo "Invalid port! Using default of 5000"
    fi
    newPorts="-p ${regPort}:5000"
    cp lib/docker-registry.auth.sh.template tmp/docker-registry-auth.tmp
    sed -ri "s@#%DEFAULTPORT%@${newPorts}@" tmp/docker-registry-auth.tmp
    cp tmp/docker-registry-auth.sh.tmp docker-registry-auth.sh
    chmod +x docker-registry-auth.sh
}

echo -e "\n\n"
echo "================================================================="
echo "       Docker-Registry-Auth SSH Auth Layer Install Utility"
echo -e "================================================================="
echo "   - To start over, simply run this utility again"
echo "   - This utility will:"
echo "     i. Add users and pubkeys to authentication container"
echo "     ii. Select and set port to listen on"
echo "     iii. Build the authentication container"
echo "   - For more information, visit: "
echo "     https://github.com/curtiszimmerman/docker-registry-auth"
echo "-----------------------------------------------------------------"
echo -e "\nAdding users to SSHd authorized users list..."

docker rmi docker-registry-auth >/dev/null 2>&1

while true; do
    echo
    read -p "Add a user? " yesno
    case ${yesno} in
        [Yy] ) getUser
        ;;
        [Nn] ) break
        ;;
        * )
        ;;
    esac
done

if [ ${#newUserNames[@]} -ne ${#newUserKeys[@]} ]; then
    echo "Something went wrong collecting new user data. Please try again."
    exit 1
fi

if [ ${#newUserNames[@]} -eq 0 ] || [ ${#newUserKeys[@]} -eq 0 ]; then
    echo "Nothing to do. Quitting."
    exit 1
fi

cp lib/Dockerfile.template tmp/Dockerfile.tmp
echo -e "\nAdding ${#newUserNames[@]} users and '${#newUserKeys[@]}' key(s)..."

for (( i=0; i<${#newUserNames[@]}; i++ ));
do
    echo "Adding user ${newUserNames[$i]}..."
    addUser "${newUserNames[${i}]}" "${newUserKeys[${i}]}"
done

# set AllowUsers in default sshd_config
cp lib/sshd_config.template tmp/sshd_config
sed -ri "s@#%ALLOWUSERS%@AllowUsers ${newUserNames[@]}@" tmp/sshd_config

# set ports and create docker-registry-auth.sh
setPort

echo -n "Creating Dockerfile... "
cp ./tmp/Dockerfile.tmp ./Dockerfile
echo "done."
echo "Running 'docker build' command to generate container..."
docker build -t="docker-registry-auth" .
echo "Container has been built! You may now run 'docker-registry-auth.sh'."
echo -e "\nFinished."
