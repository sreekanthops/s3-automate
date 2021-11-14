#!/bin/bash

#run script ./get_bucket_size.sh <bucket_name>
# usecase: get the no of objects and each object size 
# and get the total bucket size 
###########################################################
# helpers
###########################################################

function log {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1 $2"
}
function debug {
  log "DEBUG" "$1"
}
function info {
  log "INFO" "$1"
}
function error {
  log "ERROR" "$1"
}
function die {
  error "$1" && exit 1
}
function header {
  echo -e "##################################################"
  echo -e "# $1 `date -u +"%Y-%m-%dT%H:%M:%SZ"`"
  echo -e "------------------------------------------------------------------------------------"
}

###########################################################
# setup
###########################################################

bucket_name=$1

###########################################################
# main
###########################################################

# start the timer
SECONDS=0

header "activate"
####display old data based on month's/years'####
getdata()
{
###########################################################
#check size based on StorageClasses# 
###########################################################
echo "Printing the bucket size(MB's,GB's,TB's) and its no of objects"
size=$(aws s3api list-object-versions --bucket $bucket_name --query 'Versions[*].Size' | jq add) 
echo "MB:$(echo $size | awk '{print $0/1024/1024" MB"}')"
echo "GB:$(echo $size | awk '{print $0/1024/1024/1024" GB"}')"
echo "TB:$(echo $size | awk '{print $0/1024/1024/1024/1024" TB"}')"
echo "------------------------------------------------------------------------------------"

storageclasses="STANDARD STANDARD_IA GLACIER"
for i in $storageclasses
do
echo "SIZE of $i StorageClass(MB's,GB's,TB's)"
sc=$(aws s3api list-object-versions --bucket $bucket_name --query "Versions[?StorageClass=='$i'].[Size]"| sed 's/[][]//g' | sed 's/,//g' | awk '{ sum += $1 } END { print sum }')
MB=$(echo $(echo $sc | awk '{print $0/1024/1024}'))
echo "$MB MB"
GB=$(echo $(echo $sc | awk '{print $0/1024/1024/1024}'))
echo "$GB GB"
TB=$(echo $(echo $sc | awk '{print $0/1024/1024/1024/1024}'))
echo "$TB TB"
echo "------------------------------------------------------------------------------------"
if [ $i == "STANDARD" ];then
echo \$0$(bc <<< "$GB  * 0.023") | sed 's/ //g' >> price-est
elif [ $i == "STANDARD_IA" ];then
echo \$0$(bc <<< "$GB * 0.0125") | sed 's/ //g' >> price-est
else
echo \$0$(bc <<< "$GB  * 0.004") | sed 's/ //g'>> price-est
fi
done
echo "please wait, it might take sometime...!!!"
echo "------------------------------------------------------------------------------------"

###########################################################
#check size based on month's/years's# 
###########################################################
   echo ">1month," > 1.size
   echo ">2month's," > 2.size
   echo ">3month's," > 3.size
   echo ">6month's," > 6.size
   echo ">1year," > 12.size
   echo ">2year's," > 24.size
  time="1 2 3 6 12 24"
  storageclasses="STANDARD STANDARD_IA GLACIER"
  #size="StorageClass,   >1month,   >2month's,   >3month's,   >6month's,   >1year,   >2year's"
  for i in $time
  do
    for j in $storageclasses
    do
        date=$(date -d "$(date +%Y-%m-1) -$i month" +%-Y-%m-%d)      
        above=$(aws s3api list-object-versions --bucket $bucket_name --query "Versions[?LastModified<'$date' && StorageClass=='$j'].[Size]" | \
        sed 's/[][]//g' | awk '{ sum += $1 } END { print sum }')
        echo "$(echo $above | awk '{print $0/1024/1024/1024" GB"}' | sed 's/ //g' | sed "s/$/,/g" )" >> $i.size
        echo $j >> sc
        if [ $i == "1" ];then
         current=$(aws s3api list-object-versions --bucket $bucket_name --query "Versions[?LastModified>'$date' && StorageClass=='$j'].[Size]" | \
         sed 's/[][]//g' | awk '{ sum += $1 } END { print sum }')
         echo "$(echo $current | awk '{print $0/1024/1024/1024" GB"}' | sed 's/ //g' | sed "s/$/,/g" )" >> current
        fi
    done
  done
   echo "------------------------------------------------------------------------------------"
   echo "display data based on month's/year's old data for each storage class ex:1month, display morethan 1 month old data"
   echo "------------------------------------------------------------------------------------"
   sed  -i '1i STORAGECLASSES' sc
   sed  -i '1i <1month' current
   sed  -i '1i price-est/month' price-est
   cat sc  | awk -F, '{print $1,$2,$3,$4} NR==4{exit}' | sed 's/ //g' | sed "s/$/,/g" > storageclass
   pr -mts' ' storageclass current 1.size 2.size 3.size 6.size 12.size 24.size price-est | column -s, -t 
   echo "StorageClass, <1month,   >1month, >2month's, >3month's, >6month's, >1year, >2year's, price-est/month" > $bucket_name.olddata
   pr -mts' ' storageclass current 1.size 2.size 3.size 6.size 12.size 24.size price-est | column -s, -t >> $bucket_name.olddata.csv
   echo "------------------------------------------------------------------------------------"
   echo "Note: $bucket_name.olddata.csv file is created to view in excel sheet"
   echo "------------------------------------------------------------------------------------"
   rm *.size current price-est sc storageclass
}
####get the total bucket size and its no of objects####
getbucketsize()
{
ccount=$(aws s3 ls --summarize --human-readable --recursive s3://$bucket_name/  | grep "Total Objects" | cut -d ":" -f2)
echo "Number of objects(current): $ccount"
cnccount=$(aws s3api list-object-versions --bucket $bucket_name --query "Versions[*].Key" | wc -l)
echo "Number of objects(current and non current): $((cnccount-2))"
}
objects()
{
####store the list of objects from bucket in objects file####
object=$(aws s3 ls s3://$bucket_name | grep "/")
if [ ! -z "$object" ]
then
  echo "$bucket_name: folder objects found"
  yes_objects $bucket_name
else
  no_objects $bucket_name
fi
}
yes_objects()
{
aws s3 ls s3://$bucket_name | awk '{print $2}' > $bucket_name.objects.file
####get the no of objects####
cat $bucket_name.objects.file > li_objects.file
for i in $(cat li_objects.file)
do
ccount=$(aws s3 ls --summarize --human-readable --recursive s3://$bucket_name/$i | grep "Total Objects" | cut -d ":" -f2 | sed 's/ //g' | sed "s/$/,/g") >> $bucket_name.no_of_current_objects.file
count=$(aws s3api list-object-versions --bucket $bucket_name --prefix $i --query "Versions[*].Key" | wc -l) 
cnccount=$(echo $((count-2)) | sed "s/$/,/g")
echo $ccount >> $bucket_name.no_of_current_objects.file
echo $cnccount >> $bucket_name.no_of_current_n_non_current_objects.file
echo "Number of objects(current and current+non current) at $bucket_name/$i : $ccount$cnccount"
####get the size of each object#### 
size=$(aws s3api list-object-versions --bucket $bucket_name --prefix  $i --query 'Versions[*].Size' | jq add )
echo "$(echo $size | awk '{print $0/1024/1024}'| sed "s/$/,/g")" >> $bucket_name.size_of_object_MB.file
echo "$(echo $size | awk '{print $0/1024/1024/1024}'| sed "s/$/,/g")" >> $bucket_name.size_of_object_GB.file
echo "$(echo $size | awk '{print $0/1024/1024/1024/1024}'| sed "s/$/,/g")" >> $bucket_name.size_of_object_TB.file
done
 ####add comma end of line for 3 files to make easy to divide columns in csv file####
cat li_objects.file | sed "s/$/,/g" > $bucket_name.list_objects.file
merge
}
no_objects()
{
  echo "No folder objects found in $bucket_name"
  echo "no_folder_objects," > $bucket_name.list_objects.file
  ccount=$(aws s3 ls --summarize --human-readable --recursive s3://$bucket_name/ | grep "Total Objects" | cut -d ":" -f2 | sed 's/ //g' | sed "s/$/,/g")
  count=$(aws s3api list-object-versions --bucket $bucket_name --query "Versions[*].Key" | wc -l) 
  cnccount=$(echo $((count-2)) | sed "s/$/,/g")
  echo "Number of objects(current and current+non current) on $bucket_name : $ccount$cnccount"
  echo $ccount >> $bucket_name.no_of_current_objects.file
  echo $cnccount >> $bucket_name.no_of_current_n_non_current_objects.file
size=$(aws s3api list-object-versions --bucket $bucket_name --query 'Versions[*].Size' | jq add )
echo "$(echo $size | awk '{print $0/1024/1024}'| sed "s/$/,/g")" >> $bucket_name.size_of_object_MB.file
echo "$(echo $size | awk '{print $0/1024/1024/1024}'| sed "s/$/,/g")" >> $bucket_name.size_of_object_GB.file
echo "$(echo $size | awk '{print $0/1024/1024/1024/1024}'| sed "s/$/,/g")" >> $bucket_name.size_of_object_TB.file

merge
}
merge()
{
#######merge objects(*.file) files into tabular format#######
echo "objects, no_of_current_objects, no_of_current_n_non_current_objects, size_of_object(MB's), size_of_object(GB's), size_of_object(TB's)" > $bucket_name.table.csv
pr -mts' ' $bucket_name.list_objects.file $bucket_name.no_of_current_objects.file $bucket_name.no_of_current_n_non_current_objects.file $bucket_name.size_of_object_MB.file $bucket_name.size_of_object_GB.file $bucket_name.size_of_object_TB.file >> $bucket_name.table.csv
echo "------------------------------------------------------------------------------------"
echo "objects, no_of_current_objects, no_of_current_n_non_current_objects, size_of_object(MB's), size_of_object(GB's), size_of_object(TB's)" | column -s, -t 
pr -mts' ' $bucket_name.list_objects.file $bucket_name.no_of_current_objects.file $bucket_name.no_of_current_n_non_current_objects.file $bucket_name.size_of_object_MB.file $bucket_name.size_of_object_GB.file $bucket_name.size_of_object_TB.file
echo "------------------------------------------------------------------------------------"
echo "Note: $bucket_name.table.csv file is created to view in excel sheet"
echo "------------------------------------------------------------------------------------"
#######delete created files#######
rm *.file
}
getdata
getbucketsize
objects
###########################################################
# exit
###########################################################
exit $?
