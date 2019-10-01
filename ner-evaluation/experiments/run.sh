#!/bin/bash

parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

REPORTING="no"

FILES=$(find configs -name '*.yml')

CURRENT_EXPERIMENT=1
ALL_EXPERIMENTS=${#FILES[@]}

for filename in $FILES; do
    NAME=$(basename "$filename" .yml)
    echo "Running experiment $NAME ($CURRENT_EXPERIMENT/$ALL_EXPERIMENTS)."

    # report start of evaluation
    if [[ "$REPORTING" == "yes" ]]; then
        NOTIFICATION="<@UGW2TPJF8> Starting evaluation $NAME."
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$NOTIFICATION\"}" https://hooks.slack.com/services/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
    fi

    eval $(parse_yaml $filename "config_")

    mkdir -p $NAME
    cd $NAME

    rasa train nlu --nlu "../../$config_data_train_file" --config "../$filename" &>> "train.log"
    rasa test nlu --nlu "../../$config_data_test_file" --config "../$filename" &>> "test.log"

    cd ..
    mv $filename $NAME/

    # report end of evaluation
    if [[ "$REPORTING" == "yes" ]]; then
        NOTIFICATION="<@UGW2TPJF8> Finished evaluation $NAME."
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$NOTIFICATION\"}" https://hooks.slack.com/services/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
    fi

    CURRENT_EXPERIMENT=$((CURRENT_EXPERIMENT + 1))
done


