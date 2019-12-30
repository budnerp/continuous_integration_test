#!/usr/bin/env bash

#PR_COMMENT_HREF="https://api.github.com/repos/budnerp/continuous_integration_test/issues/1/comments"
#TOKEN="$1"
#PR_BASE_SHA="f8f67e442eff54e6ef434f447c61764fc9955f0b"
#PR_SHA="d4ddfa4337e65380f5ee0792d854101a6e615351"
#PR_ISSUE_HREF="https://api.github.com/repos/budnerp/continuous_integration_test/issues/1"

echo "PR_COMMENT_HREF: $PR_COMMENT_HREF"
echo "GITHUB_SHA: $GITHUB_SHA"
echo "PR_BASE_SHA: $PR_BASE_SHA"
echo "PR_SHA: $PR_SHA"
echo "PR_ISSUE_HREF: $PR_ISSUE_HREF"

remove_label() {
    PR_DELETE_LABEL_HREF="$PR_ISSUE_HREF/labels/$(echo $1 | sed "s/\s/%20/g")"
    echo "PR_DELETE_LABEL_HREF: $PR_DELETE_LABEL_HREF"
    curl -X DELETE \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    $PR_DELETE_LABEL_HREF
}

replace_label() {
    PR_REPLACE_LABEL_HREF="$PR_ISSUE_HREF/labels"
    echo "PR_REPLACE_LABEL_HREF: $PR_REPLACE_LABEL_HREF"
    curl -X PUT \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --data-binary "{ \"labels\": [\"$1\"] }" \
    $PR_REPLACE_LABEL_HREF
}


add_label() {
    PR_ADD_LABEL_HREF="$PR_ISSUE_HREF/labels"
    echo "PR_ADD_LABEL_HREF: $PR_ADD_LABEL_HREF"
    curl --silent --output /dev/null POST "$PR_ADD_LABEL_HREF" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $TOKEN" \
    --data-binary "{ \"labels\": [\"$1\"] }"
}

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

    if [ -f "phpmd_report.txt" ] && [ $(cat phpmd_report.txt | grep "No mess detected" | wc -l) -eq 0 ]; then
        add_comment "\`\`\`$(cat -v phpmd_report.txt | sed -zr "s/\"/'/g; s/\^[[[0-9]*m//g; s/\n/\\\\n/g")\`\`\`"
        exitCode=1
    fi

    echo "--- PHPMD end ---"

    echo "--- PHPCS execution start ---"
    php vendor/bin/phpcs --config-set installed_paths vendor/magento/magento-coding-standard/
    php vendor/bin/phpcs --extensions=php \
	    --standard=Magento2 \
	    --exclude=Ecg.PHP.PrivateClassMember \
	    --ignore=*/tests/* \
	    --report=full $files > phpcs_report.txt || true
    
    if [ -f "phpcs_report.txt" ] && [ -s "phpcs_report.txt" ]; then
        add_comment "\`\`\`$(cat phpcs_report.txt | sed -z "s/\"/'/g; s/\n/\\\\n/g")\`\`\`"
        exitCode=1
    fi

    echo "--- PHPCS end ---"

    if [ $exitCode -ne 0 ]; then
	#remove_label "ready for review"

	echo "--- Mark pull request as Invalid"
	#add_label "invalid"
	replace_label "invalid"

 	# send a message on Teams that PR needs Work
    else
	#remove_label "invalid"
	
	echo "--- Mark pull request as Ready For Review"
	#add_label "ready for review"
	replace_label "ready for review"
    fi
else
    echo 'No files for analysis this time'
fi

exit $exitCode
