date
ProbandGenerator=$1
K=$2
Threads=$3
Out=$4

echo "You gave
ProbandGenerator=$1
K=$2
Threads=$3
Out=$4"

if [ -z "$Out" ]
then
        echo "out file not specified"
        exit
fi

RDIR=/uufs/chpc.utah.edu/common/home/u0991464/d1/home/farrelac/RUFUS
RUFUSmodel=$RDIR/bin/ModelDist
RUFUSbuild=$RDIR/bin/RUFUS.Build
RUFUSfilter=$RDIR/bin/RUFUS.Filter
RUFUSOverlap=$RDIR/scripts/OverlapBashMultiThread.trio.sh
DeDupDump=$RDIR/scripts/HumanDedup.grenrator.tenplate
PullSampleHashes=$RDIR/cloud/CheckJellyHashList.sh
RUFUS1kgFilter=$RDIR/bin/RUFUS.1kg.filter
RunJelly=$RDIR/scripts/RunJellyForRUFUS 


if [ -e $ProbandGenerator.Jhash.sorted.min2.tab ]
then 
	echo "skipping jelly "
else 

	#mkfifo $ProbandGenerator.temp
	#/usr/bin/time -v  bash $ProbandGenerator | $RDIR/cloud/PassThroughSamCheck $ProbandGenerator.filter.chr >  $ProbandGenerator.temp &
	/usr/bin/time -v bash $RunJelly $ProbandGenerator $K $(echo $Threads -2 | bc) 2 
	rm $ProbandGenerator.temp
fi


perl -ni -e 's/ /\t/;print' $ProbandGenerator.Jhash.histo
if [ -e "$ProbandGenerator.Jhash.histo.7.7.model" ]
then
        echo "skipping model"
else
	echo "staring model"
        /usr/bin/time -v $RUFUSmodel $ProbandGenerator.Jhash.histo $K 150 $Threads 
        echo "done with model "
fi

ParentMaxE=1
MutantMinCov=$(head -2 $ProbandGenerator.Jhash.histo.7.7.model | tail -1 )

date
echo "starting RUFUS build "
let "Max= $MutantMinCov*100"
if [ -e " $ProbandGenerator.k$MutantMinCov.HashList" ]
then
        echo "Skipping build"
else
######use this one kingspeak##########
#	/usr/bin/time -v $RUFUSbuild  -c /scratch/ucgd/lustre/u0991464/RUFUS.1000g.reference/1000G.RUFUSreference.sorted.min45.tab -s $ProbandGenerator.Jhash.sorted.min2.tab -o  $ProbandGenerator.k$MutantMinCov.HashList -hs $K -mS $MutantMinCov -max 300 -t $Threads -d ' ' -mC 0

######use ths one on ono puhi humu and lonepeak#######
/usr/bin/time -v $RUFUSbuild  -c  /uufs/chpc.utah.edu/common/home/marth-d1/home/farrelac/1000gRUFUSreference/1000G.RUFUSreference.sorted.min45.tab -s $ProbandGenerator.Jhash.sorted.min2.tab -o  $ProbandGenerator.k$MutantMinCov.HashList -hs $K -mS $MutantMinCov -max 300 -t $Threads -d ' ' -mC 0
fi

echo "starting RUFUS filter"
if [ -e $ProbandGenerator.Mutations.fastq ]
then 
	echo "skipping filter"
else 
	rm  $ProbandGenerator.temp
	mkfifo $ProbandGenerator.temp
	/usr/bin/time -v  bash $ProbandGenerator | $RDIR/cloud/PassThroughSamCheck $ProbandGenerator.filter.chr >  $ProbandGenerator.temp &
	/usr/bin/time -v   $RUFUSfilter   $ProbandGenerator.k$MutantMinCov.HashList $ProbandGenerator.temp $ProbandGenerator $K 5 5 10 $(echo $Threads -2 | bc) &
	wait

fi 


if [ -e $ProbandGenerator.V2.overlap.hashcount.fastq.bam.vcf.runanyway ]
then 
	echo "skipping overlap"
else
	echo "startin RUFUS overlap"
#	/usr/bin/time -v bash $RUFUSOverlap $ProbandGenerator.Mutations.fastq 5 $ProbandGenerator $ProbandGenerator.HashList $Threads  
	/usr/bin/time -v bash $RUFUSOverlap $ProbandGenerator.Mutations.fastq 5 $ProbandGenerator $ProbandGenerator.k$MutantMinCov.HashList $Threads  
fi

echo "done with everything "



