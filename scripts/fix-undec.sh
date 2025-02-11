echo "import.log adjust"
cat import.log | perl -pe 's/\x1b.*?[mGKH]//g' > imp.log
sed -i'.orig' -e 's/Error: Resource already managed by Terraform//g' imp.log
cp imp.log import.log
echo "--> Validate Fixer"

vl=$(cat validate.json | jq '.diagnostics | length')
#echo $vl
if [[ $vl -eq 0 ]]; then
    #    echo "No validation errors"
    exit
fi
undec=$(cat validate.json | jq '.diagnostics')
count=$(echo $undec | jq '. | length' | tail -1)
count=$(expr $count - 1)
#echo $count

#
echo "Reference to undeclared resource"
#
for c in $(seq 0 $count); do
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    #echo $summ
    if [[ $summ == "Reference to undeclared resource" ]]; then
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        code=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ')
        #echo "code snip=$code"
        if [[ $code == *"="* ]]; then
            res=$(echo $code | cut -f2 -d'=')
            lhs=$(echo $code | cut -f1 -d'=' | tr -d ' |"')
        else
            res=$(echo $code)
        fi
        #echo "res=$res lhs=$lhs =$fil"
        if [[ $fil != "" ]]; then
            addr=$(echo $res | cut -f2 -d'.')
            tft=$(echo $res | cut -f1 -d'.' | tr -d '"')
            #echo "ttft=$tft  addr=$addr"

            if [[ $tft == "aws_s3_bucket" ]]; then
                addr=$(echo $addr | cut -f2 -d'_')
                tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                if [[ $tarn != "null" ]]; then
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $tarn)
                    echo "** Undeclared Fix: $res --> $tarn"
                else
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $addr)
                    echo "** Undeclared Fix: $res --> $addr"
                fi
                #echo " "
                #echo $cmd
                eval $cmd
            fi
            if [[ $tft == "aws_kms_key" ]]; then
                addr=$(echo $addr | cut -f2 -d'_')
                tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                if [[ $tarn != "null" ]]; then
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $tarn)
                    #echo " "
                    #echo $cmd
                    echo "** Undeclared Fix: $res --> $tarn"
                    eval $cmd
                fi
            fi
            if [[ $tft == "aws_iam_role" ]] || [[ $tft == "aws_codepipeline" ]]; then
                addr=$(echo $addr | cut -f2 -d'_')
                tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                tarn=${tarn//\//\\/}
                echo "**-->role tarn = $tarn $res"
                if [[ $tarn != "null" ]] && [[ $tarn != "" ]]; then
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $tarn)
                    #echo " "
                    #"echo --$cmd"
                    echo "** Undeclared Fix: $res --> $tarn"
                    eval $cmd
                fi
            fi

            if [[ $tft == "aws_sns_topic" ]]; then
                addr=$(echo $addr | cut -f2 -d'_')
                tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                tarn=${tarn//\//\\/}
                ttyp=$(grep $addr data/arn-map.dat | cut -f1 -d',' | head -1)
                if [[ $ttyp == "aws_sns_topic" ]]; then
                    if [[ $tarn != "null" ]]; then
                        cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $tarn)
                        #echo " "
                        #echo $cmd
                        echo "** Undeclared Fix: $res --> $tarn"
                        eval $cmd

                    fi
                fi
            fi

            if [[ $tft == "aws_dynamodb_table" ]]; then
                addr=$(echo $addr | cut -f2 -d'_')
                tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                tarn=${tarn//\//\\/}
                ttyp=$(grep $addr data/arn-map.dat | cut -f1 -d',' | head -1)
                if [[ $ttyp == "aws_dynamodb_table" ]]; then
                    if [[ $tarn != "null" ]]; then
                        cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $tarn)
                        #echo " "
                        #echo $cmd
                        echo "** Undeclared Fix: $res --> $tarn"
                        eval $cmd

                    fi
                fi
            fi

            if [[ $tft == "aws_sagemaker_image" ]]; then
                addr=$(echo $addr | cut -f2 -d'_')
                tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                tarn=${tarn//\//\\/}
                ttyp=$(grep $addr data/arn-map.dat | cut -f1 -d',' | head -1)

                if [[ $ttyp == "aws_sagemaker_image" ]]; then

                    if [[ $tarn != "null" ]]; then

                        cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $tarn)
                        echo " "
                        echo $cmd
                        echo "** Undeclared Fix: $res --> $tarn"
                        eval $cmd

                    fi
                fi
            fi

            #special case in cloudtrail
            if [[ $fil == "aws_cloudtrail"* ]]; then
                #echo "in file"
                if [[ $tft == *"aws_cloudwatch_log_group"* ]]; then
                    #echo "in cwl file"
                    if [[ $lhs="cloud_watch_logs_group_arn" ]]; then
                        #addr=$(echo $addr | cut -f2 -d'_')

                        tarn=$(grep $addr data/arn-map.dat | cut -f2 -d',' | head -1)
                        ttyp=$(grep $addr data/arn-map.dat | cut -f1 -d',' | head -1)
                        line=$(echo $undec | jq -r ".[${c}].range.start.line")
                        if [[ $ttyp == "aws_cloudwatch_log_group" ]]; then
                            if [[ $tarn != "null" ]]; then

                                #res2=$(echo $res | sed 's/"/\\\"/g')
                                #echo $res2

                                #cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s:*\"/g' ${fil}" $res2 $tarn)
                                cmd=$(printf "sed -i -e '%ss/.*/%s=\"%s:*\"/' ${fil}" $line $lhs $tarn)
                                #echo " "
                                #echo $cmd
                                echo "** Undeclared Fix: Cloudtrail, Cloudwatch log group $res --> $tarn:*"
                                eval $cmd

                            fi
                        fi
                    fi
                fi
            fi

            # drop in id's - ie. no ARN replacement

            if [[ $tft == "aws_iam_instance_profile" ]] || [[ $tft == "aws_nat_gateway" ]] || [[ $tft == "aws_vpc" ]] || [[ $tft == "aws_subnet" ]] || [[ $tft == "aws_security_group" ]] || [[ $tft == "aws_ec2_transit_gateway_vpc_attachment" ]] || [[ $tft == "aws_vpc_peering_connection" ]]; then
                if [[ $res == *"," ]]; then
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\",/g' ${fil}" $res $addr)
                    echo "** Undeclared Fix: $res --> $addr,"
                else
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $addr)
                    echo "** Undeclared Fix: $res --> $addr"
                fi
                eval $cmd
            fi

            if [[ $tft == "aws_servicecatalog_product" ]]; then
                addr=$(echo $res | cut -f2 -d'.' | cut -f1 -d'_')
                if [[ $addr == "prod"* ]]; then
                    cmd=$(printf "sed -i'.orig' -e 's/%s/\"%s\"/g' ${fil}" $res $addr)
                    eval $cmd
                    echo "** Undeclared Fix: $res --> $addr"
                fi
            fi
        fi
    fi
done
#
echo "enable_classiclink"
#
for c in $(seq 0 $count); do
    #echo $c
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    if [[ $summ == "Argument is deprecated" ]]; then
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        res=$(echo $undec | jq -r ".[(${c})].snippet.code" | tr -d ' ' | cut -f1 -d'=')

        if [[ $res == "enable_classiclink" ]]; then
            cmd=$(printf "sed -i'.orig' -e 's/%s/#%s/g' ${fil}" $res $res)
            echo "Depreciated classiclink Fix --> $res"
            #echo $cmd
            eval $cmd
        fi
    fi
done
#
echo "Conflicting configuration argument"
#
for c in $(seq 0 $count); do
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    #echo $c $summ
    if [[ $summ == "Conflicting configuration arguments" ]]; then
        #echo $c
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        res=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ' | cut -f1 -d'=')
        line=$(echo $undec | jq -r ".[${c}].range.start.line")
        #echo $res
        if [[ $res == "name_prefix" ]] || [[ $res == "node_group_name_prefix" ]]; then
            cmd=$(printf "sed -i -e '%ss/.*/\#/' ${fil}" $line)
            echo "Deleted conflicting name fix --> $res" | tee -a data/val-fixed.log
            #echo $cmd
            eval $cmd

        fi
    fi
done
ofil=""
#
#echo "unconfigurable attributes"
#
for c in $(seq 0 $count); do
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    if [[ $summ == "Value for unconfigurable attribute" ]]; then
        #echo $undec | jq -r ".[(${c})]"
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        res=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ' | cut -f1 -d'=')
        line=$(echo $undec | jq -r ".[${c}].range.start.line")
        code=$(echo $undec | jq -r ".[${c}].snippet.code")
        if [[ $line != "" ]]; then
            cmd=$(printf "sed -i -e '%ss/.*//' ${fil}" $line)
            echo "Unconfigurable attribute fix --> $res deleted $code"
            #echo $cmd
            eval $cmd
        else
            echo "skipping $summ"

        fi
    fi
done

#
echo "Invalid or unknown key"
#
for c in $(seq 0 $count); do
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    if [[ $summ == "Invalid or unknown key" ]]; then
        #echo $undec | jq -r ".[(${c})]"
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        res=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ' | cut -f1 -d'=')
        line=$(echo $undec | jq -r ".[${c}].range.start.line")
        #code=$(echo $undec | jq -r ".[${c}].snippet.code")
        if [[ $line != "" ]]; then
            cmd=$(printf "sed -i -e '%ss/.*/ /' ${fil}" $line)
            echo "Unconfigurable attribute fix --> $res"
            #echo $cmd
            eval $cmd
        else
            echo "skipping $summ"

        fi
    fi
done

#
echo "Missing required argument"
#
for c in $(seq 0 $count); do
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    if [[ $summ == "Missing required argument" ]]; then
        #echo $undec | jq -r ".[(${c})]"
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        res=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ' | cut -f1 -d'=')
        line=$(echo $undec | jq -r ".[${c}].range.start.line")
        code=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ')

        if [[ $line != "" ]]; then
            if [[ $code == "ipv6_netmask_length=0" ]]; then
                cmd=$(printf "sed -i -e '%ss/.*/ /' ${fil}" $line)
                echo "Missing required argument fix --> $res"
                #echo $cmd
                eval $cmd
            fi
        else
            echo "skipping $summ"

        fi
    fi
done

#
echo "Unclosed configuration block"
#

for c in $(seq 0 $count); do
    summ=$(echo $undec | jq -r ".[(${c})].summary")
    if [[ $summ == "Unclosed configuration block" ]]; then
        echo "-1-> "
        #echo $undec | jq -r ".[(${c})]"
        detl=$(echo $undec | jq -r ".[(${c})].detail")
        fil=$(echo $undec | jq -r ".[(${c})].range.filename")
        res=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ' | cut -f1 -d'=')
        line=$(echo $undec | jq -r ".[${c}].range.start.line")
        code=$(echo $undec | jq -r ".[${c}].snippet.code" | tr -d ' ')

        if [[ $detl == *"There is no closing brace for this block before the end of the file"* ]];then
            echo "Appending } to --> $fil"
            echo "}" >> $fil
        fi

 
    fi
done


