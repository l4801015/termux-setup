```
sh -c 'G="\033[32m";Y="\033[33m";R="\033[31m";B="\033[34m";X="\033[0m";
check_storage() { [ -d "$HOME/storage/downloads" ] && [ -w "$HOME/storage/downloads" ];};
run_updates() {
  printf "%b\n" "${B}▶ Updating packages (keeping configs)...$X";
  pkg update -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y;
  pkg upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y;
  printf "%b\n" "${G}✓ Updates completed!$X";
};
if check_storage; then
  printf "%b\n" "${G}✓ Storage active!$X";
  run_updates;
else
  printf "%b\n" "${Y}⚠ Starting storage setup...$X";
  termux-setup-storage;
  T=60; S=$(date +%s);
  while :; do
    N=$(date +%s); E=$((N-S));
    [ $E -ge $T ] && printf "\n%b\n" "${R}✗ Timeout!$X" && exit 1;
    if check_storage; then
      printf "\n%b\n" "${G}✓ Storage activated!$X";
      run_updates;
      exit 0;
    fi;
    printf "\r${Y}Time remaining: %02d:%02d$X" $(((T-E)/60)) $(((T-E)%60));
    sleep 1;
  done;
fi'
```
