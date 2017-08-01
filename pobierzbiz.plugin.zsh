pobierzbiz() {
	[[ -n $POBIERZBIZ_USER ]] || { echo "POBIERZBIZ_USER not defined."; return }
	[[ -n $POBIERZBIZ_PASS ]] || { echo "POBIERZBIZ_PASS not defined."; return }

	local lock="/tmp/pobierzbiz.lock"
	[[ ! -f $lock ]] || { echo "Lock file present: $lock. Remove it and run the command again."; return }
	trap "rm -f $lock" EXIT
	touch $lock

	local url="http://pobierz.biz"
	res=$(curl -s -L -b $lock --dump-header $lock -d "v=konto|main&f=loginUzt&c=aut&usr_login=$POBIERZBIZ_USER&usr_pass=$POBIERZBIZ_PASS" $url)
	res=$(curl -s -L -b $lock $url/konto)
	local uid=$(echo "$res" | grep -o -E "name='usr' value='[0-9]+'" | grep -o -E '[0-9]+')
	[[ -n $uid ]] || { echo "Failed to log in."; return }

	res=$(curl -s -L -b $lock "$url/?v=usr,pliki")
	local files=$(echo "$res" | grep -o -E 'fil\[[0-9]+\]' | sed 's/.*/\&&=on/' | tr -d '\n')
	res=$(curl -s -L -b $lock -d "c=fil&v=usr,pliki&f=usunUsera$files" $url)

	while (( $# > 0 )); do

		res=$(curl -s -L -b $lock -d "c=pob&v=usr,sprawdzone|usr,linki&f=sprawdzLinki&linki=$1%0A" $url)
		if [[ -z $(echo "$res" | grep -o -E 'link_ok\[1\]') ]]; then
			echo "Failed to download file $1"
			shift
			continue
		fi

		res=$(curl -s -L -b $lock -d "c=pob&v=usr,pliki|usr,linki&f=zapiszRozpoczete&usr=$uid&progress_type=verified&link_ok[1]=$1" $url)
		local fid=$(echo "$res" | grep -o -E 'fil\[[0-9]+\]' | grep -o -E '[0-9]+')
		res=$(curl -s -L -b $lock -d "c=fil&v=usr,pliki&fil[$fid]=on&perm=wygeneruj linki" $url)
		# first replace newlines with spaces
		res=$(echo "$res" | sed ':a;N;$!ba;s/\n/ /g' | grep -o -E "<textarea.*</textarea>" | sed -e 's/<textarea .*>\([^<]*\)<\/textarea>/\1/g')
		[[ -n $res ]] || { echo "Something went wrong."; return }

		echo "Downloading $1"
		curl -L -# -O -C - $res

		res=$(curl -s -L -b $lock -d "c=fil&v=usr,pliki&f=usunUsera&fil[$fid]=on" $url)

		shift
	done
}

