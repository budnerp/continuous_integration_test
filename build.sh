#!/usr/bin/env bash

#PR_COMMENT_HREF="https://api.github.com/repos/budnerp/continuous_integration_test/issues/1/comments"
#TOKEN="38092fba2f8d6c65e4d36448c75896c807b2cd5c"
#GITHUB_SHA=""
#PR_BASE_SHA="f8f67e442eff54e6ef434f447c61764fc9955f0b"
#PR_SHA="3acdffd24496469db03676835273d012be0e72e1"
PR_ADD_LABEL="https://api.github.com/repos/budnerp/continuous_integration_test/issues/1/labels"

    curl --silent --output /dev/null POST "$PR_ADD_LABEL" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --data-binary "{ \"labels\": [\"invalid\" }"



exit 0

add_comment() {
    curl --silent --output /dev/null POST "$PR_COMMENT_HREF" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --data-binary "{ \"body\": \"$1\" }"

    # echo "{ \"body\": \"$1\" }"
}

arrayJoin() {
  (($#)) || return 1 # At least delimiter required
  local -- delim="$1" str IFS=
  shift
  str="${*/#/$delim}" # Expand arguments with prefixed delimiter (Empty IFS)
  echo "${str:${#delim}}" # Echo without first delimiter
}

echo "--- Static code analysis ---"

echo "PR_COMMENT_HREF: $PR_COMMENT_HREF"
echo "TOKEN: $TOKEN"
echo "GITHUB_SHA: $GITHUB_SHA"
echo "PR_BASE_SHA: $PR_BASE_SHA"
echo "PR_SHA: $PR_SHA"

# get an array of modified files
files=$(git diff --name-only --diff-filter=MA $PR_BASE_SHA...$PR_SHA | grep \.php || true)
echo "Raw: $files"

# convert file list to array
declare -a modifiedFiles=($files)
echo "Array: $modifiedFiles"

# convert array to comma separated string
filesCommaSeparated=$(arrayJoin ',' "${modifiedFiles[@]}")
echo "Comma separated: $filesCommaSeparated"

# count the array
filesCount=${#modifiedFiles[@]}
echo "--- Files to analyze: $filesCount ---"

exitCode=0

if [ $filesCount -gt 0 ]
then
    echo "--- PHPMD execution start ---"

    echo "Analyze: $filesCommaSeparated"
    php vendor/bin/phpmd $filesCommaSeparated ansi \
	vendor/phpmd/phpmd/src/main/resources/rulesets/cleancode.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/codesize.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/controversial.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/design.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/naming.xml, \
	vendor/phpmd/phpmd/src/main/resources/rulesets/unusedcode.xml \
	--reportfile phpmd_report.txt

    add_comment "\`\`\`$(cat -v phpmd_report.txt | sed -zr "s/\"/'/g; s/\^[[[0-9]*m//g; s/\n/\\\\n/g")\`\`\`"

    echo "--- PHPMD end ---"

    echo "--- PHPCS execution start ---"
    php vendor/bin/phpcs --config-set installed_paths vendor/magento/magento-coding-standard/
    php vendor/bin/phpcs --extensions=php \
	    --standard=Magento2 \
	    --exclude=Ecg.PHP.PrivateClassMember \
	    --ignore=*/tests/* \
	    --report=full $files > phpcs_report.txt || true
    
    add_comment "\`\`\`$(cat phpcs_report.txt | sed -z "s/\"/'/g; s/\n/\\\\n/g")\`\`\`"
    
    echo "--- PHPCS end ---"

    if [ -f "phpmd_report.txt" ] || [ -f "phpcs_report.txt" ]; then
        exitCode=1

	# send a message on Teams that PR needs Work
    fi
else
	echo 'No files for analysis this time'
fi

exit $exitCode
