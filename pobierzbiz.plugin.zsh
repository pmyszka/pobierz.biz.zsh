pobierzbiz() {
	local lock="/tmp/pobierzbiz.lock"
	[[ ! -f $lock ]] || { echo "Lock file present: $lock. Remove it and run the command again."; return }
	trap "rm -f $lock" EXIT

	[[ -n $POBIERZBIZ_USER ]] || { echo "POBIERZBIZ_USER not defined."; return }
	[[ -n $POBIERZBIZ_PASS ]] || { echo "POBIERZBIZ_PASS not defined."; return }

	local url="http://pobierz.biz"
	local curl=(curl -s -L -b $lock)

	$curl --dump-header $lock -d "$v=konto|main&f=loginUzt&c=aut&usr_login=$POBIERZBIZ_USER&usr_pass=$POBIERZBIZ_PASS" $url > /dev/null
	local res=`$curl $url"/konto"`
	grep -s -q -e "Zalogowany jako" <<< "$res" || { echo "Failed to log in."; return }
	local uid=`grep -s -e "name='usr' value='[[:digit:]]\+'" <<< "$res" | tr -cd "[0-9]\n"`

	while (( $# > 0 )); do

		res=`$curl -d "c=pob&v=usr,sprawdzone|usr,linki&f=sprawdzLinki&linki=$1%0A" $url`
		if [[ ! -n `grep -o 'link_ok\[1\]' <<< "$res"` ]]; then
			echo "Failed to download file $1"
			shift
			continue
		fi

		res=`$curl -d "c=pob&v=usr,pliki|usr,linki&f=zapiszRozpoczete&usr=$uid&progress_type=verified&link_ok[1]=$1" $url`
		local fid=`grep -o -e "<input type='checkbox' name='fil\[[[:digit:]]\+\]' /></td><td>1</td>" <<< "$res" | grep -o -e "\[\([[:digit:]]\)\+]" | tr -cd "0-9\n"`
		res=`$curl -d "c=fil&v=usr,pliki&fil[$fid]=on&perm=wygeneruj linki" $url`
		res=`sed ':a;N;$!ba;s/\n/ /g' <<< "$res" | grep -o -e "<h2>Wygenerowane linki bezpośrednie</h2><textarea.*</textarea>" | grep -o -e "<textarea .*</textarea>" | sed -e 's,.*<textarea .*>\([^<]*\)</textarea>.*,\1,g'`
		[[ -n $res ]] || { echo "Something went wrong"; return }

		echo "Downloading $1"
		curl -L -# -O -C - $res

		$curl -d "c=fil&v=usr,pliki&f=usunUsera&fil[$fid]=on" $url > /dev/null

		shift
	done
}

