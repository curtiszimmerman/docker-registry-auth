#!/bin/bash

# gather user data
# https://github.com/curtiszimmerman/docker-registry-auth

newUserNames=();
newUserKeys=();

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

function addUser() {
    user=$1
    key=$2
    echo -n "Adding user ${user} (key ${key})... "
cat > "tmp/${user}.pub" << EOKEY
${key}
EOKEY
    newUserCommands="RUN useradd -m ${user}\nRUN mkdir -p /home/${user}/.ssh/\nCOPY tmp/${user}.pub /home/${user}/.ssh/${user}.pub\nRUN cat /home/${user}/.ssh/${user}.pub >> /home/${user}/.ssh/authorized_keys\n#%NEWUSERS%"
    echo "=-=======>(${newUserCommands})"
    sed -ri "N; s@#%NEWUSERS%@${newUserCommands}@" tmp/Dockerfile.tmp
    echo "done."
}

echo -e "\n\n"
echo "================================================================="
echo "      Docker-Registry-Auth SSH Auth Layer Add User Utility"
echo -e "================================================================="
echo "   - To start over, simply run this utility again"
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

echo -n "Creating Dockerfile... "
cp ./tmp/Dockerfile.tmp ./Dockerfile
echo "done."
echo "Running 'docker build' command to generate container..."
docker build -t="docker-registry-auth" .
echo "Container has been built! You may now run 'docker-registry-auth.sh'."
echo -e "\nFinished."
