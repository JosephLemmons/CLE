#!/usr/bin/env bash
#
## CLE : Command Live Environment
#
#* author:  Michael Arbet (marbet@redhat.com)
#* home:    https://github.com/micharbet/CLE
#* version: 2018-06-28 (Nova)
#* license: GNU GPL v2
#* Copyright (C) 2016-2018 by Michael Arbet 
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# CLE provides:
# -a colorful prompt with highlighted exit code
# -builtin aliases and functions
# -an improved command history
#
# 1. execute this file within your shell session
# 2. integrate it into your profile:
#	$ . clerc
#	$ cle deploy
#
# -use 'lssh' (ssh wrapper) to access remote systemis, CLE is seamlessly
#  started without installation
# -try lsu/lsudo (su/sudo wrappers) with the same effect
# -work in gnu screen using 'lscreen'
# -alter settings with the 'cle' command
# -store and manage your aliases with the 'aa' function
# -use 'h' as a shortcut to the classic shell history
# -check out the rich history feature with 'hh'
# -access built-in documentation: 'cle help'
# -online CLE updates from GIT

#: If you're reading this text, you probably downloaded commented version
#: of CLE named clerc-long. That is basically fine if you want to check how
#: the code is the same but the file is much longer. For general use there is
#: shortened file that has all comments introduced with '#:' removed.
#: Note other special comments - '##' introduces self documentation
#: and '#*' denotes script header

# Check if the shell is running as an interactive session otherwise CLE is
# not needed. This is required for scp compatibility
#: Note: scp is sensitive to unexpected strings printed on stdout,
#: that means you should avoid printing anything unnecessary onto
#: non interactive sessions.
if [ -t 0 -a -z "$CLE_EXE" -a -z "$BASH_EXECUTION_STRING" ];then
# warning: magic inside!

# debug stuff
[ -f $HOME/NOCLE ] && { PS1="[NOCLE] $PS1"; return; }  # debug
[ -f $HOME/CLEDEBUG ] && { CLE_DEBUG=1; echo CLE DEBUG ON; }
dbg_var () { [ $CLE_DEBUG ] && printf "%-16s = %s\n" $1 "${!1}" >/dev/tty; }
dbg_echo () { [ $CLE_DEBUG ] && echo "$*" >/dev/tty; }

# a little bit complicated way to find the absolute path
#: cross-plattform compatible way to determine absolute path to rc file
export CLE_RC=${BASH_SOURCE[0]}
CLE_RD=$(cd `dirname $CLE_RC`;pwd;)
CLE_RC=$CLE_RD/`basename $CLE_RC`

dbg_echo "-- preexec --"
dbg_echo '$0='$0
dbg_echo '$1='$1
dbg_var BASH_SOURCE[0]
dbg_var CLE_RC

#: check -m option to display /etc/motd
#: there might be more options in future and this simple check will
#: be replaced with 'getopts' then
[ "$1" = '-m' ] && export CLE_MOTD=`uptime`

# ensure bash session will be sourced with this rcfile
#: CLE can be executed as a regular script but such it would just exit without
#: effect. Following code recognizes this condition and re-executes bash with
#: the same file as resource script
[[ $0 = bash || $0 = -bash || $0 =~ /bash || $0 = -su ]] || exec /usr/bin/env bash --rcfile $CLE_RC
dbg_echo "-- afterexec --"
dbg_echo CLE resource init begins!

# who I am
#: determine username that will be inherited over the all
#: subsquent sessions initiated with lssh and su* wrappers
#: the regexp extracts username from following patterns:
#: - /any/folder/.cle-username/rcfile
#: - /any/folder/.config/cle-username/rcfile
#: - /any/folder/.config/cle/username/rcfile
#: important is the dot (hidden folder), word 'cle' and darh or slash
_N=`sed -n 's;.*cle[/-]\(.*\)/.*;\1;p' <<<$CLE_RC`
export CLE_USER=${CLE_USER:-${_N:-$USER}}
dbg_var CLE_USER

# short hostname: remove domain, leave subdomains
CLE_SHN=`hostname|sed 's;\.[^.]*\.[^.]*$;;'`
CLE_IP=`cut -d' ' -f3 <<<$SSH_CONNECTION`

# where in the deep space is CLE growing
CLE_SRC=https://raw.githubusercontent.com/micharbet/CLE
CLE_VER=`sed -n 's/^#\* version: //p' $CLE_RC`
CLE_REL=`sed 's/.*(\(.*\)).*/\1/' <<<$CLE_VER`
CLE_VER="$CLE_VER debug"

# check first run
#: check if CLE has been initiated manually from downloaded file
_N=$HOME/.cle-$CLE_USER
CLE_TRANS=mv	# default transition method (move files)
case $CLE_RC in
*/clerc*) # started manually from downloaded file
	#: CLE_1 indicates first run (downloaded file started from comandline)
	#: 'rc1' prevents accidental overwrite of deployed environment
	CLE_1=$_N/rc1
	mkdir -m 755 -p $_N
	cp $CLE_RC $CLE_1
	chmod 755 $CLE_1
	CLE_RC=$CLE_1
	CLE_TRANS=cp	# transition method (copy files, do not destroy previous environment)
	dbg_echo First run, changing some values:
	dbg_var CLE_RC
	;;
# this section converts configuration files of older releases upon transition to Nova
# all lines containig the word 'transition' will be removed in next release
*/.clerc)	# started right after upgrade from older release - 'cle update' transition
	mkdir -m 755 -p $_N # transition
	mv $CLE_RC $_N/rc && echo "CLE transition: moved .clerc into $_N/rc."
	CLE_RC=$_N/rc # transition
	mv $HOME/.cleusr-$CLE_USER $_N/tw.old && echo "CLE transition: found tweak file .cleusr-$CLE_USER, saved to $_N/tw.old (deactivated)."
	# transition hack: change hook in .bashrc
	cp .bashrc bashrc.bk	# transition: bashrc
	sed "/\.clerc/s:.*:[ -f $CLE_RC ] \&\& . $CLE_RC:" .bashrc >bashrc.sed #transition
	mv bashrc.sed .bashrc # transition
	echo "CLE transition: .bashrc edited: "; grep -A1 "Command Live" .bashrc
	;; # transition after update end
esac
#: $CLE_RH/$CLE_RD together gives folder with resource and tweak file
CLE_RH=`sed 's:\(/.*\)/\..*/.*:\1:' <<<$CLE_RC`
CLE_RD=`sed 's:/.*/\(\..*\)/.*:\1:' <<<$CLE_RC`
dbg_var CLE_RH
dbg_var CLE_RD
dbg_var CLE_RC

# find writable folder
#: there can be real situation where a remote account is restricted and have no
#: home folder. In such case CLE can be started from /tmp. Also, after su*
#: wrapper the folder containing main resource file can be and usually will be
#: in different place than current home.
#: Simply to say, this sequence ensures customized configuration for every
#: account accessed with CLE.
_D=$HOME
[ -w $_D ] || _D=/tmp/$USER
CLE_D=$_D/$CLE_RD
CLE_CF=$CLE_D/cf
mkdir -m 755 -p $CLE_D

# tweak file has same suffix as rc
_I=`sed 's:.*/rc::' <<<$CLE_RC`
CLE_TW=$CLE_RD/tw$_I
CLE_WS=${_I:1}	#: remove first character that might be '1' or '-'

# RedH to Nova transition hacks stage 2
dbg_var CLE_TRANS # transition mode
[ -f $_D/.clecf-$CLE_USER ] && $CLE_TRANS -f $_D/.clecf-$CLE_USER $CLE_D/cf && echo CLE transition: $CLE_TRANS config file
[ -f $_D/.aliases-$CLE_USER ] && $CLE_TRANS -f $_D/.aliases-$CLE_USER $CLE_D/aliases && echo CLE transition: $CLE_TRANS aliases
[ -d $_D/.cle -a $CLE_TRANS = 'mv' ] && mv -f $_D/.cle $_D/cle-old && echo CLE transition: found .cle - deactivated, saved into $HOME/dotcle-old
[ $CLE_TRANS = 'mv' ] && rm -f $_D/.cleusr-$CLE_USER* $_D/.screenrc-$CLE_USER* $_D/.clerc-remote-$CLE_USER* $_D/.aliases-$CLE_USER* $_D/clerc-* 2>/dev/null # transition: debris removal

# color table
#: initialize $_C* variables with terminal compatible escape sequences
#: following are basic ones:
_CN=`tput sgr0`
_CL=`tput bold`
_CU=`tput smul`;_Cu=`tput rmul`
_CD=`tput dim`
_CV=`tput rev`
#: The loop creates table of color codes r, g, b...
#: lower case is for dim variant, upper case stands for bright
#: try e.g 'echo $_Cg green $_CY bright yellow'
_I=0; for _N in k r g y b m c w; do
        _C=`tput setaf $_I`
        declare _C$_N=$_CN$_C
        declare _C$(tr a-z A-Z <<<$_N)=$_CL$_C
        ((_I+=1))
done
#: and... special color code for error highlight in prompt
_Ce=`tput setab 1;tput setaf 7` # err highlight


#
# Internal helper functions
#

# execute script and log its filename into CLE_EXE
# also ensure the script will be executed only once
_clexe () {
	dbg_echo clexe $*
	[ -f "$1" ] || return 1
	[[ $CLE_EXE =~ :$1 ]] && return
	CLE_EXE=$CLE_EXE:$1
	. $1
}
CLE_EXE=$CLE_RC

# boldprint
printb () { printf "$_CL$*$_CN\n";}

# simple question
ask () {
	read -p "$_CL$* (y/N) $_CN" -n 1 -s
	echo ${REPLY:=n}
	[ "$REPLY" = "y" ]
}

# banner
_banner () {
cat <<EOT

   ___| |     ____|  Command Live Environment activated
  |     |     __|    ...bit of life to the command line
  |     |     |      Learn more:$_CL cle help$_CN and$_CL cle doc$_CN
 \____|_____|_____|  Uncover the magic:$_CL less $CLE_RC$_CN
 
EOT
}

# default config
_defcf () {
	case $USER@$CLE_WS in
	root@)	CLE_CLR=red;;	#: root on workstation
	root@*) CLE_CLR=RbB;;	#: root on remote session
	*@) CLE_CLR=marley;;	#: user on workstation
	*@*) CLE_CLR=blue;;	#: user on remote session
	esac
	CLE_P0='%e \A'
	CLE_P1='\u'
	CLE_P2='%h'
	CLE_P3='\w \$'
}

# save configuration
_savecf () {
	cat <<-EOC
	# $CLE_USER $CLE_VER
	CLE_CLR=$CLE_CLR
	CLE_P0='$CLE_P0'
	CLE_P1='$CLE_P1'
	CLE_P2='$CLE_P2'
	CLE_P3='$CLE_P3'
	EOC
} >$CLE_CF

_cle_r () {
	[ "$1" != h ] && return
	printf "\n$_Cr     ,==~~-~w^, \n    /#=-.,#####\\ \n .,!. ##########!\n((###,. \`\"#######;."
	printf "\n &######\`..#####;^###)\n$_CW   (&@$_Cr^#############\"\n$_CW"
	printf "    \`&&@\\__,-~-__,\n     \`&@@@@@69@&'\n        '&&@@@&'\n$_CN\n"
}

# additional prompt escapes
#: library of enhanced prompt escape codes
#: they are introduced with % sign
_pesc () (
	C=_C$1
	P=CLE_P$1
	printf "\\[\$$C\\]"
	sed <<<${!P}\
	 -e "s/%i/$CLE_IP/g"\
	 -e "s/%h/$CLE_SHN/g"\
	 -e "s/%u/$CLE_USER/g"\
	 -e "s/%e/\\\[\$_CE\\\][\$_E]\\\[\$_CN\$$C\\\]/g"\
	 -e "s/%c\(.\)/\\\[\\\$_C\1\\\]/g"\
	 -e "s/%v\([[:alnum:]]*\)/\1=\$\1/g"
)

# prompt composer
#: This is what you see...
#: compile PS1 string from values in $CLE_COLOR and $CLE_Px
#: Note how this function is self-documented!
_setp () {
	local CC I CI
	case "$CLE_CLR" in 
	red)	CC=RrR;;
	green)	CC=GgG;;
	yellow)	CC=YyY;;
	blue)	CC=BbB;;
	cyan)	CC=CcC;;
	magenta) CC=MmM;;
	white|grey|gray) CC=NwW;;
	tricolora) CC=RBW;;
	marley)	CC=RYG;; # Bob Marley style :-) have a smoke and imagine...
	???)	CC=$CLE_CLR;; # any 3 colors
	*)	# print help on colors
		printb "Unknown color '$CLE_CLR' Select one of predefined:"
		declare -f _setp|sed -n 's/\(\<[a-z |]*\)).*/\1/p' 
		echo Alternatively make your own 3-letter code using rgbcmykw/RGBCMYKW
		echo E.g. cle color rgB
		CC=NNN
	esac
	# decode colors and prompt strings
	CC=K$CC
	PS1=""
	for I in {0..3};do
		CI=_C${CC:$I:1}
		[ -z "${!CI}" ] && printb "Wrong color code '${CC:$I:1}' in $CLE_CLR" && CI=_CN
		eval _C$I="'${!CI}'"
		PS1="$PS1`_pesc $I` "
	done
	PS1="$PS1\[\$_CN\]"
	PS2="\[\$_C1\] >>>\[\$_CN\] "
	_savecf
}

# prompt callback
#: As _prompt function is executed *every* time you push enter key its code
#: should be as simple as possible. In best case all commands here should be
#: bash internals. Those don't invoke new processes and as such they are much
#: easier to system resources.
_prompt () {
	_E=$? # save return code
	local N D T C OI=$IFS
	# highlight error code
	[ $_E = 0 ] && _CE="" || _CE="$_Ce"
	# window title & screen name
	[ "$CLE_WT" ] && printf "\033]0;$CLE_WT $PWD\007"
	[[ $TERM =~ screen ]] && echo -en "\ek$USER\e\\"
	# rich history
	history -a
	_H=`history 1`
	unset IFS
	if [ "$_H" != "$_HO"  -a -n "$_HO" ];then
		{ read -r N D T C; echo "$D $T $CLE_USER-$$ $_E $PWD $C" >>$CLE_HIST;} <<<$_H
	fi
	_HO=$_H
	IFS=$OI
}

# window title
#: This is simple window title composer
#: By 'simple' I mean it should be much improved in next version. Ideas:
#: -compose full WT string into the variable and simplyfy corresponding part
#:  in _prompt function
#: -make decision based on different environments (shell window, text console,
#:  screen session, maybe termux, etc...)
_setwt () {
	CLE_WT=''
	[[ $TERM =~ linux ]] && return # no tits on console
	[[ $CLE_RC =~ remote ]] && CLE_WT="$CLE_USER -> "
	CLE_WT=$CLE_WT$USER@$CLE_SHN-$TTY
}

# markdown filter
#: "Highly sophisticated" highlighter :-D
#: Just replaces special strings in markdown files and augments the output
#: with escape codes to highlight.
#: Not perfect, but it helps and is simple, isn't it?
mdfilter () {
	sed -e "s/^###\(.*\)/$_CL\1$_CN/"\
	 -e "s/^##\( *\)\(.*\)/\1$_CU$_CL\2$_CN/"\
	 -e "s/^#\( *\)\(.*\)/\1$_CL$_CV \2 $_CN/"\
	 -e "s/\*\*\(.*\)\*\*/$_CL\1$_CN/"\
	 -e "s/\<_\(.*\)_\>/$_CU\1$_Cu/g"\
	 -e "s/\`\`\`/$_CD~~~~~~~~~~~~~~~~~$_CN/"\
	 -e "s/\`\([^\`]*\)\`/$_Cg\1$_CN/g"
}

##
## Default aliases and functions
## -----------------------------
_defalias () {
	## ls commands aliases: l ll la lt llr l. lld
	case $OSTYPE in
	linux*) alias ls='ls --color=auto';;
	darwin*) export CLICOLOR=1;export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd;;
	FreeBSD*) alias ls='ls -G';;
	*) alias ls='ls -F' # at least some file type indication
	esac
	alias l='ls -l'
	alias ll='ls -lL'
	alias lt='ls -ltr'
	alias la='ls -al'
	alias llr='ls -lR'
	alias lld='ls -ld'
	alias l.='ls -ld .?*'
	## cd command aliases:
	## .. ...     -- up one or two levels
	## cd-        -- cd to recent dir
	## -  (dash)  -- cd to recent dir
	alias ..='cd ..'
	alias ...='cd ../..'
	alias cd-='cd -'
	## xx & cx    -- bookmark & use path; stored in $XX
	alias xx='XX=`pwd`; echo path bookmark: XX=$XX'
	alias cx='cd $XX'
	alias grep='grep --color=auto'
	alias mv='mv -i'
	alias rm='rm -i'
	# aslias to old wrappers
}

# '-' must be function, alias was troublesome
- () { cd -;}

##
## Alias management
## ----------------
CLE_ALI=$CLE_D/aliases # personalized aliases
aa () {
	local ABK=$CLE_ALI.bk TAL=$CLE_ALI.ed
	case "$1" in
	"")	## aa         -- show aliases
                alias|sed "s/^alias \(.*\)='\(.*\)'/$_CL\1$_CN	\2/";;
	-s)	## aa -s      -- save current alias set
		cp $CLE_ALI $ABK 2>/dev/null
		alias >$CLE_ALI;;
	-l)	## aa -l      -- reload aliases
		unalias -a
		. $CLE_ALI;;
	-e)	## aa -e      -- edit and reload aliases
		alias >$ABK
		cp $ABK $TAL
		vi $TAL
		mv $TAL $CLE_ALI
		aa -l
		printb Backup in: $ABK;;
	*=*)	## aa a='b'   -- create and save new alias
		alias "$*"
		aa -s;;
	*)	cle help aa
		return 1
	esac
}

##
## History tools
## -------------
#: Following settings should not be edited, nor tweaked in other files.
#: Mainly $HISTTIMEFORMAT - the rich history feature is dependent on it!
HISTFILE=$_D/.history-$CLE_USER
[ -f $HISTFILE ] || cp $HOME/.bash_history $HISTFILE
HISTCONTROL=ignoredups
HISTTIMEFORMAT="%Y-%m-%d %T "
CLE_HIST=$_D/.history-ALL

## h               -- bash 'history' wrapper
h () (
	history "$@"|while read N D T C;do
		echo "$_CB$N$_Cb $D $T $_CN$_CL$C$_CN"
	done
)

## hh [opt] [srch] -- rich history viewer
#: Rich history viewer is a stream of filters
#: 1 - selects history records based on search criteria
#: 2 - extracts required information from selected lines
#: 3 - output (directly to stdout or to 'less')
#: the code is ...i'd say ugly, to be honest
hh () (
	unset IFS	#: necessary if user manipulates with IFS value
	while getopts "cstdlf" O;do
		case $O in
		s) ONLY0=1;; ## hh -s           -- print successful commands only
		c) ONLYC=1;; ## hh -c           -- show just commands
		d) THIS=`date +%Y-%m-%d`;; ## hh -d           -- today's commands
		t) THIS=$CLE_USER-$$;; ## hh -t           -- commands from current session
		f) FMODE=1;NUM=0;OUTF="sort|uniq";; ## hh -f           -- show working folder history
		l) NUM=0; OUTF="less -r +G";; ## hh -l           -- show history with 'less'
		\?) cle help hh;return
	esac;done
	shift $((OPTIND-1))
	F1=${*:-${NUM:-100}}	## hh [opt]        -- no search; print recent 100 items
	#:
	#: Filter #1 (search by options  -t -d and/or string)
	grep -w "$THIS" $CLE_HIST | case $F1 in  #FILTER1 (search)
	0)	## hh [opt] 0      -- print all
		cat;;
	[1-9]|[1-9][0-9]|[1-9][0-9][0-9])
		## hh [opt] number -- find last N entries
		tail -$F1;;
	*)	## hh [opt] string -- search in history
		grep "$*"
	esac | while read -r D T U E P C;do #FILTER2 (format)
	 #:
	 #: Filter #2:
	 #:  - process option -f (visited folders)
	 if [ $FMODE ]; then
		[[ $P =~ ^/ ]] && echo $P
		continue
	 fi
	 #:  - process option -s (show only succeccsul commands)
	 [ $E != 0 -a "$ONLY0" ] && continue
	 #:  - colorize return code
	 case $E in
	 0)	EE=$_Cg;;
	 @)	EE=$_Cc;;
	 *)	EE=$_Cr
	 esac
	 #:  - hihglight commeted-out lines
	 [[ "$C" =~ ^# ]] && { E='#';EE=$_Cy;C=$_Cy$C$_CN;}
	 #:  - process option -c (otuput just command without other info)
	 [ "$ONLYC" ] && { [ $E = @ ] || echo $C;} ||\
		echo "$_Cb$D $T $_CB$U $EE$E $_CN$P $_CL$C$_CN"
	done | eval "${OUTF:-cat}" #FILTER3 (output)
)


# rich history record
#: used to record session init into rich history
_rhlog () {
	date "+$HISTTIMEFORMAT$CLE_USER-$$ @ $TTY [$*]" >>$CLE_HIST
}

##
## Live session wrappers
## ---------------------

# environment packer
#: grab *active* resource file, tweak file, pack it to tarball and store
#: into variable C64 as base64 encoded string.
#: Argument ($1) may contain additional suffix to filenames
#: Second outcome of _clepak is value in $RC - relative path to the resource 
#: file that should be run on remote system (it may contain the suffix)
#: Note: configuration is not packed in order to ensure unique cf on all
#:  remote accounts.
#: Note 2: _clepak is defined with curly brackets {} to pass variables RC and C64
#:  On the other side lssh is defined with () enasirng execution in own context
#:  where all new variables are local only to lssh (and _clepak)
#: Note 3: _clepak is fuction even if it is used only once and could be
#:  included directly into lssh. However, this allows to create any other
#:  remote access wrapper
_clepak () {
	cd $CLE_RH
	RC=$CLE_RD/`basename $CLE_RC`
	TW=$CLE_TW
	if [ $1 ];then
		RC=$RC$1; TW=$TW$1
		cp $CLE_RC $RC
		cp $CLE_TW $TW 2>/dev/null
	fi
	RCS="$RC $TW"
	dbg_var RCS
	#:  I've never owned this computer, I had Atari 800XL :)
	C64=`tar chzf - $RCS 2>/dev/null | base64 | tr -d '\n\r '`
}

## lssh [usr@]host   -- access remote system and take CLE along
lssh () (
	[ "$1" ] || { cle help lssh;return 1;}
	#: on CLE workstation, suffix to resource filename is added
	#: this 1. prevents overwriting on destination accounts
	#:  and 2. provides information about source of the session
	S= #: resource suffix is empty on remote sessions...
	[ $CLE_WS ] || S=-$CLE_SHN #: ...gains value only on WS
	_clepak $S
	command ssh -t $* "
		[ -w \$HOME ] && _H=\$HOME || _H=/tmp/\$USER
		[ $OSTYPE = darwin ] && _D=D || _D=d
		mkdir -m 755 -p \$_H; cd \$_H
		echo -n $C64|base64 -\$_D |tar xzf -;
		exec $RC -m"
)

#: Following are su* wrappers of different kinds including kerberos
#: version 'ksu'. They are basically simple, you see. Environment is not
#: packed and transferred when using them. Instead the original files from
#: user's home folder are used.
## lsudo [user]      -- sudo wrapper; root is the default account
lsudo () (
	sudo -i -u ${1:-root} $CLE_RC
)

## lsu [user]        -- su wrapper
#: known issue - on debian systems controlling terminal is detached in case 
#: a command ($CLE_RC) is specified, use 'lsudo' instead
lsu () (
	S=
	[[ $OSTYPE =~ [Ll]inux ]] && S="-s $BASH"
	eval su -l $S ${1:-root} $CLE_RC
)

## lksu [user]       -- ksu wrapper
#: Kerberized version of 'su'
lksu () (
	ksu ${1:-root} -a -c $CLE_RC
)

## lscreen [name]    -- gnu screen wrapper, join your recent session or start new
## lscreen -j [name] -- join other screen sessions, ev. search by name
#: GNU screen wrapper is here 1) because of there was no way to tell screen
#: program to start CLE on more than first window and, 2) to allow easily
#: join detached own session and/or join cooperative session with more
#: participants.
lscreen () (
	#: get name of the screen to search and join
	#: base of session name is $CLE_USER and this can be extended
	NM=$CLE_USER${1:+-$1}
	[ "$1" = -j ] && NM=${2:-.}
	#: list all screens with that name and find how many of them are there
	SCRS=`screen -ls|sed -n "/$NM/s/^[ \t]*\([0-9]*\.[^ \t]*\)[ \t]*.*/\1/p"`
	NS=`wc -w <<<$SCRS`
	if [ $NS = 0 ]; then
		[ "$1" = -j ] && echo "No screen to join" && return 1
		#: No session with given name found, prepare to start new session
		SCF=$CLE_D/screenrc
		SN=$TTY-CLE.$NM
		_rhlog screen -S $SN
		_scrc >$SCF
		screen -c $SCF -S $SN $CLE_RC
	else
		#: is there only one such session or more?
		if [ $NS = 1 ]; then SN=$SCRS
		else
			#: we found more screens with simiilar names, choose one!
			printb "${_CU}Current '$NM' sessions:"
			PS3="$_CL choose # to join: $_CN"
			select SN in $SCRS;do
				[ $SN ] && break
			done
		fi
		_rhlog screen -x $SN
		#: send message to other screen, then join the session
		screen -S $SN -X echo "$CLE_USER joining"
		screen -x $SN
	fi
)

# screenrc generator
#: This generates nice configuration file with cool features:
#:  - always visible status line with list of windows, hostname and clock
#:  - feature to quickly switch using Ctrl+Left/Right Arrows
#:  - reads good old $HOME/.screenrc
#: Own screenrc file is necessary because otherwise it wouldn't start CLE in
#: subsequent windows created with 'C-a C-c' (note the bind commands, above
#: mentioned features are cool but this part is the important one)
_scrc () {
cat <<-EOS
	altscreen on
	autodetach on
	# enables shift-PgUp/PgDn
	termcapinfo xterm* ti@:te@
	# change window with ctrl-left/right
	bindkey "^[[1;5D" prev
	bindkey "^[[1;5C" next
	defscrollback 9000
	hardstatus alwayslastline 
	hardstatus string '%{= Kk}%-w%{+u KC}%n %t%{-}%+w %-=%{KG}$CLE_SHN%{Kg} %c'
	bind c screen $CLE_RC
	bind ^c screen $CLE_RC
	source $HOME/.screenrc
EOS
}

# Transition warnings after wrappers rename
ssg () { printb "Warning: ssg is deprecated, use 'lssh' instead"; sleep 1;lssh "$@"; }       # transition
ksuu () { printb "Warning: ksuu is deprecated, use 'lksu' instead"; sleep 1; lksu "$@"; }    # transition
suu () { printb "Warning: suu is deprecated, use 'lsu' instead"; sleep 1; lsu "$@"; }        # transition
sudd () { printb "Warning: sudd is deprecated, use 'lsudo' instead"; sleep 1; lsudo "$@"; }  # transition
scrn () { printb "Warning: scrn is deprecated, use 'lscreen' instead"; sleep 3; lscreen "$@"; }  # transition

# session startup
#: run default resources only on non-login sessions
[[ $0 =~ ^- ]] || { _clexe /etc/profile; _clexe $HOME/.bashrc; }

#: Note that default aliases are always renewed
#: That's because there are system dependencies
_clexe $CLE_ALI
_defalias

PROMPT_DIRTRIM=2
PROMPT_COMMAND=_prompt
shopt -s checkwinsize

#: Enhnace PATH by user's own bin folder
[[ -d $HOME/bin && ! $PATH =~ $HOME/bin ]] && PATH=$PATH:$HOME/bin

# completions
#: Command 'cle' completion
#: as an addition, prompt strings are filled for convenience :)
_clecmp () {
	#: list of subcommands, this might be reworked to have possibility of expansion
	#: with modules (TODO)
	#: 'cle deploy' is hidden intentionaly as user should do it only on when really needed
	local A=(color p0 p1 p2 p3 time title mod env update reset reload doc help)
	local C
	COMPREPLY=()
	case $3 in
	p0) COMPREPLY="'$CLE_P0'";;
	p1) COMPREPLY="'$CLE_P1'";;
	p2) COMPREPLY="'$CLE_P2'";;
	p3) COMPREPLY="'$CLE_P3'";;
	esac
	[ "$3" != "$1" ] && return
	for C in ${A[@]}; do
		[[ $C =~ ^$2 ]] && COMPREPLY+=($C)
	done
	}
complete -F _clecmp cle

#: lssh there are two possibilities of ssh completion _known_hosts is more common, _ssh is better
declare -F _known_hosts >/dev/null && complete -F _known_hosts lssh
declare -F _ssh >/dev/null && complete -F _ssh lssh


# session record
TTY=`tty|sed 's;[/dev];;g'`
_rhlog ${STY:-${SSH_CONNECTION:-$CLE_RC}}

# load modules from .cle folder
for _I in $CLE_D/mod-*;do
	_clexe $_I
done

# config & tweaks
_clexe $HOME/.cle-local
_clexe $CLE_RH/$CLE_TW
_clexe $CLE_CF || { _banner;_defcf;}
CLE_P3=`sed 's/%>/\\\\\$/g' <<<$CLE_P3`  # transition fix for removed '%>'
_setp
_setwt

[ "$CLE_MOTD" ] && { cat /etc/motd;echo;echo $CLE_MOTD;unset CLE_MOTD; }

# check first run
[ $CLE_1 ] && cat <<-EOT
 It seems you started CLE running '$CLE_RC'
 Since this is the first run, consider setup in your profile.
 Following command will hook CLE in $HOME/.bashrc:
$_CL	cle deploy
EOT

##
## CLE command & control
## ---------------------
cle () {
	local C I MM BRC NC
	C=$1;shift
	#: find if there is additional function or module installed and
	#: execute that code
	if declare -f _cle_$C >/dev/null;then
		_cle_$C $*
		return $?
	elif [ -f $CLE_D/cle-$C ]; then
		. $CLE_D/cle-$C $*
		return $?
	fi
	#: execute built-in 'cle' subcommand
	case "$C" in
	color)	## cle color COLOR -- set prompt color
		CLE_CLR=$1
		_setp;;
	p?)	## cle p0-p3 [str] -- show/define prompt parts
		I=CLE_P${C:1:1}
		[ "$*" ] && eval "$I='$*'" || echo "$I='${!I}'"
		_setp;;
	time)	## cle time [off]  -- toggle server time in prompt
		[ "$1" = off ] && CLE_P0=%e || CLE_P0='%e \A'
		_setp;;
	title)	## cle title [off] -- toggle window title
		[ "$1" = off ] && CLE_WT='' || _setwt;;
	deploy) ## cle deploy      -- hook CLE into user's profile
		cp $CLE_RC $CLE_D/rc
		CLE_RC=$CLE_D/rc
		unset CLE_1
		I='# Command Live Environment'
		BRC=$HOME/.bashrc
		grep -A1 "$I" $BRC && printb CLE is already hooked in .bashrc && return 1
		ask "Do you want to add CLE to .bashrc?" || return
		echo -e "\n$I\n[ -f $CLE_RC ] && . $CLE_RC\n" | tee -a $BRC
		cle reload;;
	update) ## cle update      -- install fresh version of CLE
		NC=$CLE_D/rc.new
		curl -k $CLE_SRC/master/clerc >$NC	# always update from master branch
		C=`sed -n 's/^#\* version: //p' $NC`
		[ "$C" ] || { echo "Download error"; return 1; }
		echo current: $CLE_VER
		echo "new:     $C"
		MM=`diff $CLE_RC $NC` && { echo No difference; return 1;}
		ask Do you want to see diff? && cat <<<"$MM"
		ask Do you want to install new version? || return
		BRC=$CLE_D/rc.bk
		cp $CLE_RC $BRC
		chmod 755 $NC
		mv -f $NC $CLE_RC
		cle reload
		printb New CLE activated, backup saved here: $BRC;;
	reload) ## cle reload      -- reload CLE
		unset CLE_EXE
		. $CLE_RC
		echo CLE $CLE_VER;;
	reset)	## cle reset       -- reset configuration
		rm -f $CLE_CF
		cle reload;;
	mod)	## cle mod         -- cle module management
		#: this is just a fallback to initialize modularity
		#: downloaded cle-mod overrides this code (see the beginning
		#: of 'cle' function)
		ask Activate CLE modules? || return
		I=cle-mod
		MM=$CLE_D/$I
		curl -k $CLE_SRC/$CLE_REL/modules/$I >$MM
		grep -q "# $I:" $MM || { printb Module download failed; rm -f $MM; return 1;}
		cle mod "$@";;
	env)	## cle env         -- print CLE_* variables
		for I in ${!CLE_*};do printf "$_CL%-12s$_CN%s\n" $I "${!I}";done;;
	doc)	## cle doc         -- show documentation
		I=`curl -sk $CLE_SRC/$CLE_REL/doc/index.md`
		[[ $I =~ LICENSE ]] || { echo Unable to get documentation;return 1;}
		PS3="$_CL doc # $_CN"
		select C in $I;do
			[ $C ] && curl -sk $CLE_SRC/$CLE_REL/doc/$C |mdfilter|less -r; break
		done;;
	help)	## cle help [fnc]  -- show help
		# double hash denotes help content
		_C=`ls $CLE_D/cle-* 2>/dev/null`
		awk -F# "/[\t ]## *$1|^## *$1/ { print \$3 }" ${CLE_EXE//:/ } $_C;;
	"")	_banner
		sed -n 's/^#\*\(.*\)/\1/p' $CLE_RC;; # header
# DEBUG
	ls)	printb CLE_D: $CLE_D; ls -l $CLE_D; printb CLE_RD: $CLE_RD; ls -l $CLE_RD;; #debug
	debug)	CLE_DEBUG=$1; dbg_var CLE_DEBUG;; #debug
	pak)	_clepak "$@" ; base64 -d <<<$C64| tar tzvf -;; #debug
# DEBUG
	*)	echo unimplemented: cle $C
		echo check cle help
		return 1
	esac
}

# remove temporary stuff
unset SUDO_COMMAND _D _I _N _C
fi
# that's all folks...

