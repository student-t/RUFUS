date
Parent1Generator=$1
Parent2Generator=$2
SiblingGenerator=$3
ProbandGenerator=$4
K=$5
Threads=$6
Out=$7

echo "You gave
Parent1Generator=$1
Parent2Generator=$2
SiblingGenerator=$2
ProbandGenerator=$4
K=$5
Threads=$6
Out=$7
"

if [ -z "$Out" ]
then
        echo "out file not specified"
        exit
fi

RDIR=/home/ubuntu/work/RUFUS
RUFUSmodel=$RDIR/bin/ModelDist
RUFUSbuild=$RDIR/bin/RUFUS.Build
RUFUSfilter=$RDIR/bin/RUFUS.Filter
RUFUSOverlap=$RDIR/scripts/OverlapBashMultiThread.sh
DeDupDump=$RDIR/scripts/HumanDedup.grenrator.tenplate
PullSampleHashes=$RDIR/cloud/CheckJellyHashList.sh
RUFUS1kgFilter=$RDIR/bin/RUFUS.1kg.filter
RunJelly=$RDIR/cloud/RunJellyForRUFUS


/usr/bin/time -v bash $RunJelly $Parent1Generator $K $(echo $Threads -1 | bc)
/usr/bin/time -v bash $RunJelly $Parent2Generator $K $(echo $Threads -1 | bc)
/usr/bin/time -v bash $RunJelly $SiblingGenerator $K $(echo $Threads -1 | bc)
/usr/bin/time -v bash $RunJelly $ProbandGenerator $K $(echo $Threads -1 | bc)


perl -ni -e 's/ /\t/;print' $ProbandGenerator.Jhash.histo
perl -ni -e 's/ /\t/;print' $Parent1Generator.Jhash.histo
perl -ni -e 's/ /\t/;print' $Parent2Generator.Jhash.histo
perl -ni -e 's/ /\t/;print' $SiblingGenerator.Jhash.histo

if [ -e "$ProbandGenerator.Jhash.histo.7.7.model" ]
then
        echo "skipping model"
else
	echo "staring model"
        /usr/bin/time -v $RUFUSmodel $ProbandGenerator.Jhash.histo $K 150 $Threads 
        echo "done with model "
fi

if [ -e "$SiblingGenerator.Jhash.histo.7.7.model" ]
then 
	 echo "skipping model"
else
	 echo "staring model"
	/usr/bin/time -v $RUFUSmodel $SiblingGenerator.Jhash.histo $K 150 $Threads
	echo "done with model "
fi 

ParentMaxE=0
MutantMinCov=$(head -2 $ProbandGenerator.Jhash.histo.7.7.model | tail -1 )
SiblingMinCov=$(head -2 $SiblingGenerator.Jhash.histo.7.7.model | tail -1 )
echo "$ParentMaxE \n $MutantMinCov \n"

date
echo "starting RUFUS build "
let "Max= $MutantMinCov*100"
if [ -e "Family.Unique.HashList" ]
then
        echo "Skipping build"
else
	echo "wellshit"
	/usr/bin/time -v ../RUFUS/cloud/jellyfish-MODIFIED-merge/bin/jellyfish merge $Parent1Generator.Jhash  $Parent2Generator.Jhash $SiblingGenerator.Jhash $ProbandGenerator.Jhash >  Family.Unique.HashList
fi

echo "Mut cov = $MutantMinCov and SiblingMinCov = $SiblingMinCov"
if [ -e $ProbandGenerator.k$K_c$MutantMinCov.HashList.prefilter ]
then 
	echo "skipping $ProbandGenerator.HashList pull "
else

	/usr/bin/time -v bash $PullSampleHashes $ProbandGenerator.Jhash Family.Unique.HashList $MutantMinCov > $ProbandGenerator.k$K_c$MutantMinCov.HashList.prefilter
fi 

if [ -e $SiblingGenerator.k$K_c$SiblingMinCov.HashList.prefilter ]
then 
	echo "skipping $SiblingGenerator.HashList pull"
else
	/usr/bin/time -v bash $PullSampleHashes $SiblingGenerator.Jhash Family.Unique.HashList $SiblingMinCov > $SiblingGenerator.k$K_c$SiblingMinCov.HashList.prefilter
fi 


if [ -e $ProbandGenerator.k$K_c$MutantMinCov.HashList ]
then 
	echo "skipping 1kg filter"
else
	 /usr/bin/time -v ../RUFUS/cloud/RUFUS.search.1kg -hf <(awk '{print $1 "\t" $2}' $ProbandGenerator.k$K_c$MutantMinCov.HashList.prefilter ) -o $ProbandGenerator.k$K_c$MutantMinCov.HashList  -c $RDIR/cloud/1000G.RUFUSreference.sorted.min45.tab -hs 25
fi 

if [ -e $SiblingGenerator.k$K_c$SiblingMinCov.HashList ]
then
        echo "skipping 1kg filter"
else
         /usr/bin/time -v  ../RUFUS/cloud/RUFUS.search.1kg -hf <(awk '{print $1 "\t" $2}' $SiblingGenerator.k$K_c$SiblingMinCov.HashList.prefilter ) -o $SiblingGenerator.k$K_c$SiblingMinCov.HashList  -c $RDIR/cloud/1000G.RUFUSreference.sorted.min45.tab -hs 25
fi

echo "done with RUFUS build "

echo "startin RUFUS filter"
if [ -e $ProbandGenerator.Mutations.fastq ]
then 
	echo "skipping filter"
else 
	rm  $ProbandGenerator.temp
	mkfifo $ProbandGenerator.temp
	/usr/bin/time -v  bash $ProbandGenerator >  $ProbandGenerator.temp &
	/usr/bin/time -v   $RUFUSfilter  $ProbandGenerator.k$K_c$MutantMinCov.HashList $ProbandGenerator.temp $ProbandGenerator $K 5 5 10 $(echo $Threads -1 | bc) &
wait
fi 

if [ -e $ProbandGenerator.V2.overlap.hashcount.fastq.bam.vcf ]
then 
	echo "skipping overlap"
else
	echo "startin RUFUS overlap"
	/usr/bin/time -v bash $RUFUSOverlap $ProbandGenerator.Mutations.fastq 5 $ProbandGenerator $ProbandGenerator.k$MutantMinCov.HashList $Threads $ProbandGenerator.Jhash $SiblingGenerator.Jhash $Parent1Generator.Jhash $Parent2Generator.Jhash 
fi

echo "startin RUFUS filter"
if [ -e $SiblingGenerator.Mutations.fastq ]
then 
	echo "skipping filter" 
else
	rm  $SiblingGenerator.temp
	mkfifo $SiblingGenerator.temp
	/usr/bin/time -v  bash $SiblingGenerator >  $SiblingGenerator.temp &
	/usr/bin/time -v   $RUFUSfilter  $SiblingGenerator.k$K_c$SiblingMinCov.HashList $SiblingGenerator.temp $SiblingGenerator $K 5 5 10 $(echo $Threads -1 | bc) &
wait
fi

if [ -e $ProbandGenerator.V2.overlap.hashcount.fastq.bam.vcf ]
then
	echo "skipping overlap"
else
	echo "startin RUFUS overlap"
	/usr/bin/time -v bash $RUFUSOverlap $SiblingGenerator.Mutations.fastq 5 $SiblingGenerator $SiblingGenerator.k$SiblingMinCov.HashList $Threads $SiblingGenerator.Jhash $ProbandGenerator.Jhash $Parent1Generator.Jhash $Parent2Generator.Jhash

fi


echo "done with everything "



