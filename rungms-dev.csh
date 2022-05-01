#!/bin/csh -f
################################################################################
# Define GMSPATH
################################################################################
set GMSPATH=`pwd`
################################################################################
# Source install.info
################################################################################
if ( -e $GMSPATH/install.info ) then
   source $GMSPATH/install.info
else
   echo "Please run 'config' first, to set up GAMESS compiling information" >> /dev/stderr
   exit 4
endif
################################################################################
# Command-line arguments
################################################################################
set INPUT=$1
set VERNO=$2
set NCPUS=$3
set CPUS_PER_NODE=$4
set LOGN=$5
################################################################################
# Define TARGET
################################################################################
set TARGET=sockets
set primary_node=`hostname`
################################################################################
# Define variables that will impact run at the top of the script
################################################################################
limit stacksize 131072
setenv MKL_SERIAL YES
setenv MKL_NUM_THREADS 1
################################################################################
# Define DDI_RHS and DDI_RCP
################################################################################
setenv DDI_RSH ssh
setenv DDI_RCP scp
################################################################################
# Setup LD_LIBRARY_PATH
################################################################################
if (! $?LD_LIBRARY_PATH ) setenv LD_LIBRARY_PATH
# Math Library (optional for soft-linking cases)
if (-d $GMS_MATHLIB_PATH) setenv LD_LIBRARY_PATH ${GMS_MATHLIB_PATH}:${LD_LIBRARY_PATH}
################################################################################
# Setup PATH
################################################################################
################################################################################
# Scheduler
################################################################################
echo "COBALT has assigned the following compute nodes to this run:"
uniq $COBALT_NODEFILE
################################################################################
# Define local scratch (SCR)
################################################################################
if ( -d /scratch ) then
   set SCR=/scratch
else if ( -d /local ) then
   if ( -d /local/$USER ) then
      set SCR=/local/$USER
   else
      set SCR=/local
   endif
else
   set SCR=`pwd`/scratch
endif
if (! -d $SCR) srun mkdir -p $SCR
################################################################################
# Define user scratch (USERSCR)
################################################################################
if (! $?USERSCR ) then
   set USERSCR=$HOME/restart
endif
if (! -d $USERSCR) mkdir -p $USERSCR
################################################################################
# Process command-line arguments
################################################################################
if ($INPUT:r.inp != $INPUT) set INPUT=$1.inp
if (null$VERNO == null) set VERNO=00
if (null$NCPUS == null) set NCPUS=1
if (null$CPUS_PER_NODE == null) then
   set NNODES=1
else
   set CPUS_PER_NODE = $4
   @ NNODES = $NCPUS / $CPUS_PER_NODE
endif
if (null$LOGN == null)  set LOGN=0
################################################################################
# Input processing
################################################################################
set JOB=`basename $INPUT`
#
if ($JOB:r.inp == $JOB) then
  set JOB=$JOB:r
  set nonomatch
  foreach file ("$SCR/$JOB."*)
     if (-f "$file" && -w "$file") rm -v "$file"
  end
  unset nonomatch
  unset file
endif
#
echo "Copying input file $JOB.inp to your run's scratch directory..."
#
if (-e $INPUT) then
   cp  $INPUT  $SCR/$JOB.F05
else
   if (-e $GMSPATH/tests/travis-ci/$JOB.inp) then
      cp  $GMSPATH/tests/travis-ci/$JOB.inp  $SCR/$JOB.F05
   else if (-e $GMSPATH/tests/travis-ci/parallel/$JOB.inp) then
      cp  $GMSPATH/tests/travis-ci/parallel/$JOB.inp  $SCR/$JOB.F05
   else
      echo "Input file $JOB.inp does not exist." >> /dev/stderr
      echo "This job expected the input file to be in directory `pwd`" >> /dev/stderr
      echo "Please fix your file name problem, and resubmit." >> /dev/stderr
      exit 4
   endif
endif
################################################################################
# GAMESS resource files
################################################################################
source $GMSPATH/gms-files.csh
if (-e $HOME/.gmsrc) then
   echo "reading your own $HOME/.gmsrc"
   source $HOME/.gmsrc
endif
################################################################################
# GDDI resource files setup
################################################################################
set ngddi=`grep -i '^ \$GDDI' $SCR/$JOB.F05 | grep -iv 'NGROUP=0 ' | wc -l`
if ($ngddi > 0) then
   set GDDIjob=true
   echo "This is a GDDI run, keeping various output files on local disks"
   set echo
   setenv  OUTPUT $SCR/$JOB.F06
   setenv   PUNCH $SCR/$JOB.F07
   unset echo
else
   set GDDIjob=false
endif
################################################################################
# REMD resource files setup
################################################################################
set runmd=`grep -i runtyp=md $SCR/$JOB.F05 | wc -l`
set mremd=`grep -i mremd= $SCR/$JOB.F05 | grep -iv 'mremd=0 ' | wc -l`
if (($mremd > 0) && ($runmd > 0) && ($ngddi > 0)) then
   set GDDIjob=false
   set REMDjob=true
   echo "This is a REMD run, keeping various output files on local disks"
   set echo
   setenv TRAJECT     $SCR/$JOB.F04
   setenv RESTART $USERSCR/$JOB.rst
   setenv    REMD $USERSCR/$JOB.remd
   unset echo
   set GDDIinp=(`grep -i '^ \$GDDI' $JOB.inp`)
   set numkwd=$#GDDIinp
   @ g = 2
   @ gmax = $numkwd - 1
   while ($g <= $gmax)
      set keypair=$GDDIinp[$g]
      set keyword=`echo $keypair | awk '{split($1,a,"="); print a[1]}'`
      if (($keyword == ngroup) || ($keyword == NGROUP)) then
         set nREMDreplica=`echo $keypair | awk '{split($1,a,"="); print a[2]}'`
         @ g = $gmax
      endif
      @ g++
   end
   unset g
   unset gmax
   unset keypair
   unset keyword
else
   set REMDjob=false
endif
################################################################################
# Remove restart files from previous run
################################################################################
if (-f "$CASINO"  && -w "$CASINO")  echo "rm $CASINO"  && rm "$CASINO"
if (-f "$CIMDMN"  && -w "$CIMDMN")  echo "rm $CIMDMN"  && rm "$CIMDMN"
if (-f "$CIMFILE" && -w "$CIMFILE") echo "rm $CIMFILE" && rm "$CIMFILE"
if (-f "$COSDATA" && -w "$COSDATA") echo "rm $COSDATA" && rm "$COSDATA"
if (-f "$COSPOT"  && -w "$COSPOT")  echo "rm $COSPOT"  && rm "$COSPOT"
if (-f "$GAMMA"   && -w "$GAMMA")   echo "rm $GAMMA"   && rm "$GAMMA"
if (-f "$MAKEFP"  && -w "$MAKEFP")  echo "rm $MAKEFP"  && rm "$MAKEFP"
if (-f "$MDDIP"   && -w "$MDDIP")   echo "rm $MDDIP"   && rm "$MDDIP"
if (-f "$OPTHES1" && -w "$OPTHES1") echo "rm $OPTHES1" && rm "$OPTHES1"
if (-f "$OPTHES2" && -w "$OPTHES2") echo "rm $OPTHES2" && rm "$OPTHES2"
if (-f "$PUNCH"   && -w "$PUNCH")   echo "rm $PUNCH"   && rm "$PUNCH"
if (-f "$QMWAVE"  && -w "$QMWAVE")  echo "rm $QMWAVE"  && rm "$QMWAVE"
if (-f "$RESTART" && -w "$RESTART") echo "rm $RESTART" && rm "$RESTART"
if (-f "$TRAJECT" && -w "$TRAJECT") echo "rm $TRAJECT" && rm "$TRAJECT"
################################################################################
# DDI Communication Choice pre-run
################################################################################
set PPN=$CPUS_PER_NODE
if (null$PPN == null) set PPN=$NCPUS
@ NPROCS = $NCPUS + $NCPUS
#
setenv HOSTFILE $SCR/$JOB.nodes.mpd
if (-f "$HOSTFILE" && -w "$HOSTFILE") rm "$HOSTFILE"
touch $HOSTFILE
#
uniq $COBALT_NODEFILE > $HOSTFILE
set NNODES=`wc -l $HOSTFILE`
set NNODES=$NNODES[1]
#
echo "#########################################################################"
echo HOSTFILE $HOSTFILE contains
cat $HOSTFILE
echo "#########################################################################"
#
if ($NNODES > 1) then
   set NCPUS=$SCR/$JOB.nodes.cpus
   touch $NCPUS
   uniq -c $COBALT_NODEFILE > $NCPUS
endif
#
if (-e $NCPUS) then
   set HOSTLIST=()
   @ CPU=1
   set ncores=0
   while ($CPU <= $NNODES)
      set node=`sed -n -e "$CPU p" <$NCPUS`
      set c=`echo $node | awk '{ print $1 }'`
      set n=`echo $node | awk '{ print $2 }'`
      set HOSTLIST=($HOSTLIST ${n}:cpus=$c)
      @ CPU++
      @ ncores += $c
   end
   echo Using $NNODES nodes and $ncores cores from $NCPUS.
   set NCPUS=$ncores
   goto skipsetup
endif
#
if ($NCPUS == 1) then
   set NNODES=1
   set HOSTLIST=(`hostname`)
endif
#
if ($NCPUS > 1) then
   switch ( `hostname` )
      default:
         echo " "
         echo Assuming a single but multicore node.
         if($LOGN == 0) then
            set NNODES=1
            set HOSTLIST=(`hostname`:cpus=$NCPUS)
         else
            @ NNODES = $NCPUS / $LOGN
            echo Splitting it into $NNODES logical nodes with $LOGN cores each.
            set HOSTLIST=()
            set i=1
            while ($i <= $NNODES)
               set HOSTLIST=($HOSTLIST `hostname`:cpus=$LOGN)
               @ i++
            end
         endif
         echo " "
   endsw
endif
#
skipsetup:
echo "#########################################################################"
echo HOSTLIST contains
echo $HOSTLIST
echo "#########################################################################"
################################################################################
# GDDI pre-run setup
################################################################################
if ($GDDIjob == true) then
   @ n=2   # master in master group already did 'cp' above
   while ($n <= $NNODES)
      set host=$HOSTLIST[$n]
      set host=`echo $host | cut -f 1 -d :` # drop anything behind a colon
      echo $DDI_RCP $SCR/$JOB.F05 ${host}:$SCR/$JOB.F05
           $DDI_RCP $SCR/$JOB.F05 ${host}:$SCR/$JOB.F05
      @ n++
   end
endif
################################################################################
# REMD pre-run
################################################################################
if ($REMDjob == true) then
   source $GMSPATH/tools/remd.csh $TARGET $nREMDreplica
   if ($status > 0) exit $status
endif
################################################################################
# Clear system of stray semaphores from the user after launch
################################################################################
if ( -f $GMSPATH/bin/my_ipcrm ) $GMSPATH/bin/my_ipcrm
################################################################################
# Executable Information
################################################################################
echo The execution path is
echo $path
echo " "
echo The library path is
echo $LD_LIBRARY_PATH
echo " "
echo The dynamically linked libraries for this binary are
echo $GMSPATH/gamess.$VERNO.x:
echo " "
ldd $GMSPATH/gamess.$VERNO.x
echo " "
if ((-x $GMSPATH/gamess.$VERNO.x) && (-x $GMSPATH/ddikick.x)) then
else
   echo "The GAMESS executable gamess.$VERNO.x" >> /dev/stderr
   echo "or else the DDIKICK executable ddikick.x" >> /dev/stderr
   echo "could not be found in directory $GMSPATH," >> /dev/stderr
   echo "or else they did not properly link to executable permission." >> /dev/stderr
   exit 8
endif
################################################################################
# Launch Header
################################################################################
echo "----- GAMESS execution script 'rungms-dev' -----"
echo "Input file      : $INPUT"
echo "GAMESS Binary   : $VERNO"
echo "Number of CPUS  : $NCPUS"
echo "Number of nodes : $NNODES"
echo "Logical nodes   : $LOGN"
echo This job is running on host $primary_node
echo under operating system `uname` at `date` with $TARGET communication mode
echo "Available scratch disk space (Kbyte units) at beginning of the job is"
df -k $SCR
echo "GAMESS temporary binary files will be written to $SCR"
echo "GAMESS supplementary output files will be written to $USERSCR"
################################################################################
# GAMESS Launch
################################################################################
set echo
$GMSPATH/ddikick.x $GMSPATH/gamess.$VERNO.x $JOB \
    -ddi $NNODES $NCPUS $HOSTLIST \
    -scr $SCR < /dev/null
unset echo
################################################################################
# GDDI file juggling
################################################################################
if ($GDDIjob == true) cp $SCR/$JOB.F07 $USERSCR/$JOB.dat
################################################################################
# Accounting info
################################################################################
echo ----- accounting info -----
echo Files used on the primary node $primary_node were:
ls -lF $SCR/$JOB.*
set nmax=${#HOSTLIST}
set lasthost=$HOSTLIST[1]
@ n=2
while ($n <= $nmax)
   set host=$HOSTLIST[$n]
   set host=`echo $host | cut -f 1 -d :`
   if ($host != $lasthost) then
      echo Files from $host are:
      $DDI_RSH $host -l $USER -n "ls -l $SCR/$JOB.*"
      set lasthost=$host
   endif
   @ n++
end
################################################################################
# Scratch clean-up
################################################################################
set nonomatch
foreach file ("$SCR/$JOB.F"*)
   if (-f "$file" && -w "$file") rm "$file"
end
unset nonomatch
unset file
#
set nmax=${#HOSTLIST}
set lasthost=$HOSTLIST[1]
@ n=2
while ($n <= $nmax)
   set host=$HOSTLIST[$n]
   set host=`echo $host | cut -f 1 -d :`
   if ($host != $lasthost) then
      echo Files from $host are:
      $DDI_RSH $host -l $USER -n "find '$SCR' -maxdepth 1 -type f -writable -name '$JOB.F*' -exec rm {} \;"
      set lasthost=$host
   endif
   @ n++
end
################################################################################
# Clear system of stray semaphores from the user after launch
################################################################################
if ( -f $GMSPATH/bin/my_ipcrm ) $GMSPATH/bin/my_ipcrm
################################################################################
# Date/Time
################################################################################
date
time
exit
