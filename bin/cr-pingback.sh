#!/bin/bash
#
#3> <> prov:specializationOf <https://github.com/timrdf/csv2rdf4lod-automation/blob/master/bin/cr-pingback.sh>;
#3>    prov:wasDerivedFrom   <https://github.com/timrdf/csv2rdf4lod-automation/blob/master/bin/cr-publish-droid-to-endpoint.sh> .
#
# See also:
#    https://github.com/timrdf/csv2rdf4lod-automation/wiki/Aggregating-subsets-of-converted-datasets
#
# Environment variables used:
#
#    CSV2RDF4LOD_HOME                  - to access the scripts.
#    CSV2RDF4LOD_BASE_URI              - 
#    CSV2RDF4LOD_BASE_URI_OVERRIDE     - can override the above.
#    CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID - to know which source-id this dataset should be placed within.
#    CSV2RDF4LOD_PUBLISH_DATAHUB_METADATA_OUR_BUBBLE_ID - to know which dataset to update on http://datahub.io/dataset/???
#
#    (see https://github.com/timrdf/csv2rdf4lod-automation/wiki/CSV2RDF4LOD-environment-variables)
#
# Usage:
#
# Example usage:
# 

HOME=$(cd ${0%/*} && echo ${PWD%/*})
export PATH=$PATH`$HOME/bin/util/cr-situate-paths.sh`
export CLASSPATH=$CLASSPATH`$HOME/bin/util/cr-situate-classpaths.sh`
opt=${HOME%/*}
CSV2RDF4LOD_HOME=${CSV2RDF4LOD_HOME:?$HOME}

# cr:data-root cr:source cr:directory-of-datasets cr:dataset cr:directory-of-versions cr:conversion-cockpit
ACCEPTABLE_PWDs="cr:data-root cr:source"
if [ `${CSV2RDF4LOD_HOME}/bin/util/is-pwd-a.sh $ACCEPTABLE_PWDs` != "yes" ]; then
   ${CSV2RDF4LOD_HOME}/bin/util/pwd-not-a.sh $ACCEPTABLE_PWDs
   exit 1
fi

if [[ -z "$CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID" && \
      `${CSV2RDF4LOD_HOME}/bin/util/is-pwd-a.sh cr:source` == "yes" ]]; then
   export CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID=`cr-source-id.sh`
fi

see="https://github.com/timrdf/csv2rdf4lod-automation/wiki/Aggregating-subsets-of-converted-datasets"
CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID=${CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID:?"not set; see $see"}

TEMP="_"`basename $0``date +%s`_$$.tmp

sourceID=$CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID
datasetID=`basename $0 | sed 's/.sh$//'`
versionID=`date +%Y-%b-%d`

graphName=${CSV2RDF4LOD_BASE_URI_OVERRIDE:-$CSV2RDF4LOD_BASE_URI}/source/$sourceID/dataset/$datasetID/version/$versionID

if [[ "$1" == "--help" ]]; then
   echo "usage: `basename $0` [--target] [-n] [--clear-graph] [--force] [named_graph_URI | cr:auto | .]"
   echo ""
   echo "  Find all metadata Turtle files in any conversion cockpit, "
   echo "    archive them into a new versioned dataset, and "
   echo "      load it into a virtuoso sparql endpoint."
   echo ""
   echo "         --target : return the name of graph that will be loaded; then quit."
   echo "               -n : perform dry run only; do not load named graph."
   echo "    --clear-graph : clear the named graph."
   echo "          --force : send to datahub.io regardless of the 7-day throttle."
   echo
   echo "  named_graph_URI : use graph name given"
   echo "          cr:auto : use named graph $graphName"
   echo "                . : print to stdout"
   exit 1
fi

if [ "$1" == "--target" ]; then
   # a conversion:VersionedDataset:
   # e.g. http://purl.org/twc/health/source/tw-rpi-edu/dataset/cr-publish-tic-to-endpoint/version/2012-Sep-07
   echo $graphName
   exit 0
fi

dryRun="false"
if [ "$1" == "-n" ]; then
   dryRun="true"
   dryrun.sh $dryrun beginning
   shift 
fi

clearGraph="false"
if [ "$1" == "--clear-graph" ]; then
   clearGraph="true"
   shift
fi

force="false"
if [ "$1" == "--force" ]; then
   force="true"
   shift
fi

#if [ "$1" != "cr:auto" ]; then
#   graphName="$1"
#   shift 
#fi

if [[ `${CSV2RDF4LOD_HOME}/bin/util/is-pwd-a.sh cr:source` == "yes" ]]; then
   pushd .. &> /dev/null
fi

cockpit="$sourceID/$datasetID/version/$versionID"

if [ ! -d $cockpit/source ]; then
   mkdir -p $cockpit/source
   mkdir -p $cockpit/automatic
fi
rm -rf $cockpit/source/*

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
echo "$cockpit/source/void.rdf <- ${CSV2RDF4LOD_BASE_URI_OVERRIDE:-$CSV2RDF4LOD_BASE_URI}/void"

within_last_week=`find $sourceID/$datasetID -mindepth 4 -name void.rdf -atime +6 | tail -1`
if [[ -z "$within_last_week" || "$force" == "true" ]]; then
   curl -sH "Accept: application/rdf+xml" -L ${CSV2RDF4LOD_BASE_URI_OVERRIDE:-$CSV2RDF4LOD_BASE_URI}/void > $cockpit/source/void.rdf
   if [[ -e $opt/DataFAQs/services/sadi/ckan/add-metadata.py ]]; then
      echo "http://datahub.io/dataset/$CSV2RDF4LOD_PUBLISH_DATAHUB_METADATA_OUR_BUBBLE_ID <- $cockpit/source/void.rdf"
      echo "add-metadata.py's input:"
      valid-rdf.sh -v $cockpit/source/void.rdf
      guess-syntax.sh $cockpit/source/void.rdf
      void-triples.sh $cockpit/source/void.rdf
      python $opt/DataFAQs/services/sadi/ckan/add-metadata.py $cockpit/source/void.rdf > $cockpit/source/response.rdf
      echo "add-metadata.py's output:"
      valid-rdf.sh -v $cockpit/source/response.rdf
      void-triples.sh $cockpit/source/response.rdf
      cat $cockpit/source/response.rdf
   else
      echo "ERROR: `basename $0` could not find $opt/DataFAQs/services/sadi/ckan/add-metadata.py"
   fi
else
   echo "INFO: `basename $0` skipping push to datahub.io b/c has been done in the last week."
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

#pushd $cockpit &> /dev/null
#   echo
#   echo aggregate-source-rdf.sh --link-as-latest source/* 
#   if [ "$dryRun" != "true" ]; then
#      aggregate-source-rdf.sh --link-as-latest source/* 
#      # WARNING: ^^ publishes even with -n b/c it checks for CSV2RDF4LOD_PUBLISH_VIRTUOSO
#   fi
#popd &> /dev/null
#
#if [ "$clearGraph" == "true" ]; then
#   echo
#   echo "Deleting $graphName" >&2
#   if [ "$dryRun" != "true" ]; then
#      publish/bin/virtuoso-delete-$sourceID-$datasetID-$versionID.sh
#   fi
#fi
#
#if [ "$dryRun" != "true" ]; then
#   pushd $cockpit &> /dev/null
#      publish/bin/virtuoso-load-$sourceID-$datasetID-$versionID.sh
#   popd &> /dev/null
#fi

# if [ "$CSV2RDF4LOD_PUBLISH_COMPRESS" == "true" ]; then
# fi

dryrun.sh $dryrun ending
