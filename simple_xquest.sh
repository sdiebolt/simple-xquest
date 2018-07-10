#!/bin/bash

# xquest_prepare - a script to prepare and start xquest/xprophet runs.

# This script can download and install the xQuest/xProphet 2.1.1 pipeline and its
# dependencies (Apache 2, Perl libraries, etc.) and prepare the necessary
# directory structure.

# Runs on Ubuntu 18.04 LTS.

##### FUNCTIONS #####

function download {
  # Downloading xQuest/xProphet
  printf "Downloading xQuest/xProphet... "
  cd $HOME/xquest
  if [ "$verbose" = "1" ]; then
    wget -q --user=xquest --password=xprophet http://proteomics.ethz.ch/xquest2_www//downloads/V2_1_1.tar
  else
    wget -q --user=xquest --password=xprophet http://proteomics.ethz.ch/xquest2_www//downloads/V2_1_1.tar > /dev/null
  fi
  printf "Done.\n\n"

  # Extracting the archive
  printf "Extracting tar... "
  if [ "$verbose" = "1" ]; then
    tar -xvf V2_1_1.tar
  else
    tar -xf V2_1_1.tar > /dev/null
  fi
  rm V2_1_1.tar
  printf "Done.\n\n"

  # Installing dependencies
  printf "Installing dependencies...\nThe script will ask you your password to run apt-get, install dos2unix and run cpan.
For the latter, please use the default configuration.\n"
  cd V2_1_1/xquest/installation
  chmod 755 install_packages.sh
  ./install_packages.sh
  printf "Done.\n\n"

  # Installing xQuest/xProphet
  printf "Installing xQuest/xProphet...\n"
  printf "Please use the default location for the stylesheet (/var/www/).\n"
  sed '1s/.*/INSTALLDIR=$HOME\/xquest\/V2_1_1\/xquest/' install_xquest.sh > install_xquest_new.sh
  mv install_xquest.sh install_xquest.sh.bak
  mv install_xquest_new.sh install_xquest.sh
  chmod 755 install_xquest.sh
  ./install_xquest.sh
  printf "Done.\n\n"

  # Configuring Apache 2
  sudo service apache2 restart
  printf "Configuring the Apache 2 web server...\nThe script will ask you your password.\n"
  sudo chmod -R 777 $HOME/xquest/results
  # apache2.conf
  sudo cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
  sudo bash -c 'echo "ServerName localhost" >> /etc/apache2/apache2.conf'
  sudo bash -c 'echo "ScriptAlias /cgi-bin/ /var/www/cgi-bin/" >> /etc/apache2/apache2.conf'
  sudo bash -c 'echo "Options +ExecCGI" >> /etc/apache2/apache2.conf'
  sudo bash -c 'echo "AddHandler cgi-script .cgi .pl .py" >> /etc/apache2/apache2.conf'
  # serve-cgi-bin.conf
  sudo cp /etc/apache2/conf-available/serve-cgi-bin.conf /etc/apache2/conf-available/serve-cgi-bin.conf.bak
  sudo sed -i "s#/usr/lib/#/var/www/#g" /etc/apache2/conf-available/serve-cgi-bin.conf
  sudo sed -i "/Require all granted/d" /etc/apache2/conf-available/serve-cgi-bin.conf
  sudo sed -i "s/Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch/Options +ExecCGI/g" /etc/apache2/conf-available/serve-cgi-bin.conf
  # 000-default.conf
  sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
  sudo sed -i "s#DocumentRoot /var/www/html/#DocumentRoot /var/www#g" /etc/apache2/sites-available/000-default.conf
  # Enabling CGI module
  sudo a2enmod cgi
  # Creating cgi-bin folder and symlinks
  sudo mkdir /var/www/cgi-bin/
  sudo ln -s $HOME/xquest/V2_1_1/xquest/cgi/ /var/www/cgi-bin/xquest
  sudo ln -s $HOME/xquest/results/ /var/www/results
  # Configuring xQuest for Apache 2
  sed -i "s/xquest-desktop/$(hostname -s)/g" $HOME/xquest/V2_1_1/xquest/modules/Environment.pm
  sed -i "s/xquestvm/xquest-ubuntu/g" $HOME/xquest/V2_1_1/xquest/modules/Environment.pm
  sed -i "s#\\\/home\\\/xquest\\\/xquest#\\\/home\\\/$(whoami)\\\/xquest\\\/V2_1_1\\\/xquest#g" $HOME/xquest/V2_1_1/xquest/modules/Environment.pm
  sed -i "s#/home/xquest/results#$HOME/xquest/results#g" $HOME/xquest/V2_1_1/xquest/conf/web.config

  # Restarting Apache 2 server
  sudo service apache2 restart
  printf "Done.\n\n"
}

function usage {
  printf "AUTHOR: Samuel Diebolt\n\n"

  printf "INFORMATION: This script downloads and installs the xQuest/xProphet
pipeline and its dependencies (Apache 2, Perl libraries, etc.)
and prepares the necessary directory structure in $HOME/xquest.\n\n"

  printf "USAGE: xquest_prepare -option [parameter]\n\n"

  printf "OPTIONS: Values in [] are the default values that are used if
the option is not provided.\n\n"
  printf -- "\t-i | --interactive: run in interactive mode.\n\n"
  printf -- "\t-D | --download: download and install xQuest/xProphet and its
        dependencies.\n\n"
  printf -- "\t-d | --directory [run]: analysis directory name.
        e.g.: $HOME/xquest/analysis/run.\n\n"
  printf -- "\t-m | --mzxml [./]: path to the mzXML files, including ending '/' e.g.
        /path/to/mzXML/.\n\n"
  printf -- "\t-f | --fasta [./my_db.fasta]: path to the FASTA database, e.g.
        /path/to/fasta/my_db.fasta.\n\n"
  printf -- "\t-x | --xquest: run xQuest after preparations are done.
        Options xmlmode and pseudosh are used for xQuest.\n\n"
  printf -- "\t-p | --xprophet: run xProphet after preparations are done."
  printf -- "\t-v | --verbose: verbose mode."
  printf -- "\t-h | --help: prints this help.\n\n"

  printf "EXAMPLE: xquest_prepare -l files -p /path/to/mzXML/.\n"
}

##### MAIN #####

# Adding xQuest bin to PATH
case ":$PATH:" in
  *:$HOME/xquest/V2_1_1/xquest/bin:*) printf "PATH correctly set.\n\n"
                                      ;;
  *)  printf "Setting PATH... "
      cp $HOME/.bashrc $HOME/.bashrc.bak
      echo "export PATH=$PATH:$HOME/xquest/V2_1_1/xquest/bin" >> $HOME/.bashrc
      source $HOME/.bashrc
      printf "Done.\n\n"
      ;;
esac

dl=
xquest=
xprophet=
directory="run"
mzxml="./"
fasta="./"


# The script should not be run as root
if [ "$EUID" = 0 ]
  then echo "Please do not run this script as root."
  exit
fi

# Command line options
while [ "$1" != "" ]; do
  case $1 in
    -D | --download)      dl=1
                          ;;
    -d | --directory)     shift
                          directory=$1
                          ;;
    -m | --mzxml)         shift
                          mzxml=$1
                          ;;
    -f | --fasta)         shift
                          fasta=$1
                          ;;
    -x | --xquest)        xquest=1
                          ;;
    -p | --xprophet)      xprophet=1
                          ;;
    -v | --verbose        verbose=1
                          ;;
    -h | --help)          usage
                          exit
                          ;;
    *)                    usage
                          exit 1
  esac
  shift
done

# Creating directory structure
printf "Creating directory structure... "
mkdir -p $HOME/xquest/{results,analysis/$directory/{mzxml,db}}
printf "Done.\n\n"

# Download and install xQuest/xProphet and its dependencies
if [ "$dl" = "1" ]; then
  download
fi

# Move the mzxml and fasta files to the analysis directory, create definition files
# and reverse database
printf "Copying mzxml and fasta files to $HOME/xquest/analysis/$directory/... "
cd $HOME/xquest/analysis/$directory/
cp $mzxml/*.mzXML mzxml/
cp $fasta db/database.fasta
if [ "$verbose" = "1" ]; then
  xdecoy.pl -db db/database.fasta
  runXquest.pl -getdef
else
  xdecoy.pl -db db/database.fasta > /dev/null
  runXquest.pl -getdef > /dev/null
fi
printf "Done.\n\n"

# Configuring definition files
read -p "You will now configure xquest.def. Press enter to continue."
nano xquest.def
read -p "You will now configure xmm.def. Press enter to continue."
nano xmm.def

# Starting the search
if [ "$xquest" = "1" ]; then
  printf "Configuring the search...\n\n"
  ls mzxml/ | sed 's/\(.*\)\..*/\1/' > files
  pQuest.pl -list files -path $HOME/xquest/analysis/$directory/mzxml/
  printf "Done.\n\n"
  printf "Running the search...\n\n"
  runXquest.pl -list files -xmlmode -pseudosh
  printf "Done.\n\n"

  # Merging result files
  printf "Merging result files... "
  resultfolder=$HOME/xquest/analysis/$directory/results$directory
  printf $resultfolder
  if [ "$verbose" = "1" ]; then
    mergexml.pl -list resultdirectories_fullpath -resdir $resultfolder
  else
    mergexml.pl -list resultdirectories_fullpath -resdir $resultfolder > /dev/null
  fi
  printf "Done.\n\n"

  # Annotate search results
  printf "Annotating search results... "
  cd $resultfolder
  if [ "$verbose" = "1" ]; then
    annotatexml.pl -xmlfile merged_xquest.xml -out annotated_xquest.xml -native
  else
    annotatexml.pl -xmlfile merged_xquest.xml -out annotated_xquest.xml -native > /dev/null
  fi
  printf "Done.\n\n"

  if [ "$xprophet" = "1" ]; then
    # Configuring xProphet analysis
    printf "Configuring xProphet analysis...\n"
    if [ "$verbose" = "1" ]; then
      xprophet.pl
    else
      xprophet.pl > /dev/null
    fi
    read -p "You will now configure xproph.def. Press enter to continue."
    nano xproph.def
    printf "Done.\n\n"

    # Starting xProphet analysis
    printf "Running xProphet... "
    if [ "$verbose" = "1" ]; then
      xprophet.pl -in annotated_xquest.xml -out xquest.xml
    else
      xprophet.pl -in annotated_xquest.xml -out xquest.xml > /dev/null
    fi
    printf "Done.\n\n"
  else
    mv annotated_xquest xquest.xml
  fi

  # Copying results to the results folder for the web server
  printf "Copying results to the web server...\nThe script will ask your password to give the correct permissions to Apache 2.\n"
  cp -R $resultfolder $HOME/xquest/results
  sudo chmod -R 777 $HOME/xquest/results/results$directory
  printf "Done.\n\n"

  # Displaying the result manager
  printf "Display the result manager.\n"
  firefox localhost/cgi-bin/xquest/resultsmanager.cgi
fi
