#===============================================================================
#   PROMPT
#===============================================================================
#export PS1="\[\e[0;35m\]\u \[\e[0;36m\]\t \[\e[0;33m\]\w \[\e[0;33m\]:: \[\e[0m\]"
#Shell prompt customisation
#PS1="\[\033[0;41m\]\u @\t> \w: \[\033[0m\]"
#export PS1
#export PS1="\[\e[0;35m\]\u \[\e[0;36m\]\t \[\e[0;33m\]\w \[\e[0;33m\]:: \[\e[0m\]"
#export PS1="\[\e[0;35m\]\u \[\e[0;36m\]\t \[\e[0;33m\]\w \[\e[0m\]"
#export PS1="\[\e[0;35m\]\u \[\e[0;36m\]\t \[\e[1;32m\]\w \[\e[1;32m\]:: \[\e[0m\]" # Grey directory info
#export PS1="\[\e[0;36m\]\t \[\e[1;32m\]\w \[\e[1;32m\]:: \[\e[0m\]" # Green directory with blue time.
export PS1="\[\e[0;36m\]\t \[\e[0;32m\]\w \[\e[0;92m\]:: \[\e[0m\]" # Bright Green directory with blue time.
#===============================================================================
#   PATH EXPORTS
#===============================================================================
# Setting PATH for EPD-6.3-1
# The orginal version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/EPD64.framework/Versions/Current/bin:${PATH}"
export PATH
# MacPorts Installer addition on 2010-11-26_at_17:56:28: adding an appropriate PATH variable for use with MacPorts.
##
# Your previous /Users/tarek_allam/.bash_profile file was backed up as /Users/tarek_allam/.bash_profile.macports-saved_2010-11-26_at_17:56:28
##
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
# Finished adapting your PATH environment variable for use with MacPorts.
# adding path for bash script to allow battery status bar in tmux
export PATH="/Users/tarek_allam/Documents/tmux/bin:$PATH"
# added by Anaconda3 2.1.0 installer
export PATH="/Users/tarek_allam/anaconda3/bin:$PATH"
# path for mysql
export PATH="/usr/local/mysql/bin:$PATH"
# mongodb PATH
export PATH="/Users/tarek_allam/mongodb/bin:$PATH"
# jMusic classpath
export CLASSPATH="/Users/tarek_allam/jMusic/jmusic.jar:Users/tarek_allam/jMusic/inst/:$CLASSPATH"

source "`brew --prefix grc`/etc/grc.bashrc"
export PATH="/usr/local/sbin:$PATH"
#===============================================================================
#   COLOUR CUSTOMISATION
#===============================================================================
export CLICOLOR=1
export LSCOLORS=Exfxcxdxbxegedabagacad # Blue
#export LSCOLORS=GxFxCxDxBxegedabagaced - Green
#export LSCOLORS=exfxcxdxbxegedabagacad - Blue
#export LSCOLORS=Cxfxcxdxbxegedabagacad
#export LSCOLORS=Dxfxcxdxbxegedabagacad - Yellow
export GREP_OPTIONS="--color=auto"
#===============================================================================
#   ALIASES
#===============================================================================
# force tmux to use 256 colours
#alias tmux="TERM=screen-256color-bce tmux"
# ipython 
alias pylab="ipython -pylab"
# force tmux to use 256 colours
alias tmux="tmux -2"
# azure mysql connection shortcut
alias dbcw="mysql -h eu-cdbr-azure-north-b.cloudapp.net -u b868b961e0bfe6 -p554e5f66 -D MarkingP2PDB"
# listing in colour and easy quitting
alias ls="ls -Gh"
alias cl="clear"
alias la="ls -la"
alias qq="exit"
alias grep="grep -E"
# put computer to sleep
alias sleep="sudo shutdown -s now"
# colourful version of cat command
alias pat="pygmentize -g"
# python2 enviroment
alias python2="source activate python2"
alias pclose="source deactivate"
# application shortcuts
alias chrome="open /Applications/Google\ Chrome.app/"
alias poker="open /Applications/PokerStarsUK.app/"
alias fire="open -a /Applications/Firefox.app/"
# sublime shortcut
alias sub="open -a /Applications/Sublime\ Text\ 2.app/"
alias rr="R CMD BATCH "
alias www="cd ~/Google\ Drive/tarekallam_webpage/Ceevee10/"
#===============================================================================
#   MISC.
#===============================================================================
MKL_NUM_THREADS=1
export MKL_NUM_THREADS

#Find .bashrc file and source.
if [ -f ~/.localrc ]; then
	   source ~/.localrc
fi