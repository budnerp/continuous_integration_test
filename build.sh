#!/usr/bin/env bash

echo "\nStatic code analysis"
# FILES=$(git diff --name-only --diff-filter=MA origin/develop...$GITHUB_SHA | grep \.php || true)
FILES="code/planet.php code/planet-copy.php"
if [ ! -z "$FILES" -a "$FILES" != " " ]
then
    echo 'File(s) to be analyzed:'
    echo $FILES

    echo "\nPHPMD execution"
    for file in $FILES
    do
        echo "Analyze: $file"
        php vendor/bin/phpmd $file xml \
		vendor/phpmd/phpmd/src/main/resources/rulesets/cleancode.xml, \
		vendor/phpmd/phpmd/src/main/resources/rulesets/codesize.xml, \
		vendor/phpmd/phpmd/src/main/resources/rulesets/controversial.xml, \
		vendor/phpmd/phpmd/src/main/resources/rulesets/design.xml, \
		vendor/phpmd/phpmd/src/main/resources/rulesets/naming.xml, \
		vendor/phpmd/phpmd/src/main/resources/rulesets/unusedcode.xml \
		--reportfile phpmd_all_rules.xml
    done


#    if [ -f "phpmd_all_rules.xml" ]; then
#        add_comment "\"$(cat phpmd_all_rules.xml | sed "s/\"/'/g")\""
#    fi

#    echo "\nPHPCS execution"
#    ${PHPPATH} html/vendor/bin/phpcs --config-set installed_paths html/vendor/magento/magento-coding-standard/
#    ${PHPPATH} html/vendor/bin/phpcs --extensions=php --standard=Magento2 --exclude=Ecg.PHP.PrivateClassMember --ignore=*/tests/* --report=json $FILES > phpcs.json || true
#    ${PHPPATH} html/vendor/bin/phpcs --extensions=php --standard=Magento2 --exclude=Ecg.PHP.PrivateClassMember --ignore=*/tests/* --report=full $FILES || true
#    cat phpcs.json
#
#    if [ -f "phpcs.json" ]; then
#        add_comment "\"$(cat phpcs.json | sed "s/\"/'/g")\""
#    fi
else
	echo 'No files for analysis found'
fi

exit 0
