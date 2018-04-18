#!/bin/bash
# helper function that performs the final tagging action
function tag_commit () {
	echo tagging commit with tag: $1
	if ( (git tag $1) && (git push origin $1) )
	then
		echo "Version tag bump successfully completed!"
		exit 0
	else
		errorMessage="Error encountered while trying to tag and push the tag to origin! Is this repository connected to a remote repo called origin?"
		echo $errorMessage >&2
		exit 4
	fi
}

# check input parameter was provided
if [ -z $1 ]
then
	errorMessage="No service name provided. Correct usage: ./tagger.sh serviceName"
	echo $errorMessage >&2
	exit 1
else
	serviceName=$1
fi

# make sure this is a feature-merge-to-master commit / hotfix commit
latestCommitMessage=$(git show -s --format=%B)
currentBranchName=$(git branch | grep "*")
if !(((grep --quiet --ignore-case "master" <<< $currentBranchName) && (grep --ignore-case --quiet "merge" <<< $latestCommitMessage)) || (grep --quiet --ignore-case "hotfix" <<< $currentBranchName))
then
	errorMessage="Script must be run on a merge commit to master branch (to bump major version) or a hotfix branch (to bump minor version)"
	echo $errorMessage >&2
	exit 2
fi

# get most recent tag
mostRecentTag=$(git describe --tags --match "$serviceName*")
if [ -z $mostRecentTag ]
then
	echo 'Could not find version tag for service '$serviceName'. It will receive tag of version 1.0'
	tag_commit $serviceName-1.0 # script ends here inside tag_commit call since we're tagging this as version 1.0
else
	echo "This service's most recent tag is: "$mostRecentTag
fi


# pull the version number from the tag
versionRegexp="([0-9]+)\\.([0-9]+)" # Regexp that matches number.number"
if [[ $mostRecentTag =~ $versionRegexp ]]
then
	majorVersion=${BASH_REMATCH[1]}
	minorVersion=${BASH_REMATCH[2]}
else
	errorMessage="Latest service tag doesn't have a version in it. Please fix manually using 'git tag'!  (don't forget to push the tag to the remote repository)"
	echo $errorMessage >&2
	exit 3
fi

#check to see this commit isn't tagged already
recentTagHash=$( git log --pretty=format:'%H' -n 1 $serviceName-$majorVersion.$minorVersion)
currentCommitHash=$( git log --pretty=format:'%H' -n 1 )
if [ "$recentTagHash" == "$currentCommitHash" ]
then
	echo "Current commit is already tagged: ["$mostRecentTag"]. Tagger will now exit."
	exit 0
fi

# bump version number according to whether this is a feautre/hotfix branch
if (grep --quiet --ignore-case "hotfix" <<< $currentBranchName)
then
	let minorVersion++
else
	let majorVersion++
fi

#tag with latest version calculated
tag_commit $serviceName-$majorVersion.$minorVersion
