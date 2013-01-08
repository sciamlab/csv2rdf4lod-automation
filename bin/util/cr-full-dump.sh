#!/bin/bash
#
#3> <> prov:specializationOf <https://github.com/timrdf/csv2rdf4lod-automation/blob/master/bin/util/cr-full-dump.sh>;
#3>    prov:wasDerivedFrom   <cr-publish-droid-to-endpoint.sh>;
#3>    rdfs:seeAlso          <https://github.com/timrdf/csv2rdf4lod-automation/wiki/One-click-data-dump> .
#
# Gather all versioned dataset dump files into one enormous dump file.
# This is highly redundant, but can be helpful for those that "just want the data"
# and don't want to crawl the VoID dataDumps to get it.

see="https://github.com/timrdf/csv2rdf4lod-automation/wiki/CSV2RDF4LOD-not-set"
CSV2RDF4LOD_HOME=${CSV2RDF4LOD_HOME:?"not set; source csv2rdf4lod/source-me.sh or see $see"}

see="https://github.com/timrdf/csv2rdf4lod-automation/wiki/Aggregating-subsets-of-converted-datasets"
CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID=${CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID:?"not set; see $see"}

see="https://github.com/timrdf/csv2rdf4lod-automation/wiki/Aggregating-subsets-of-converted-datasets"
CSV2RDF4LOD_BASE_URI=${CSV2RDF4LOD_BASE_URI:?"not set; see $see"}

# cr:data-root cr:source cr:directory-of-datasets cr:dataset cr:directory-of-versions cr:conversion-cockpit
ACCEPTABLE_PWDs="cr:data-root"
if [ `${CSV2RDF4LOD_HOME}/bin/util/is-pwd-a.sh $ACCEPTABLE_PWDs` != "yes" ]; then
   ${CSV2RDF4LOD_HOME}/bin/util/pwd-not-a.sh $ACCEPTABLE_PWDs
   exit 1
fi

TEMP="_"`basename $0``date +%s`_$$.tmp

sourceID=$CSV2RDF4LOD_PUBLISH_OUR_SOURCE_ID
datasetID=`basename $0 | sed 's/.sh$//'`
versionID='latest' # Doing it every day is a waste of space for this use case. `date +%Y-%b-%d`

cockpit="$sourceID/$datasetID/version/$versionID"
sdv=`echo $CSV2RDF4LOD_BASE_URI | perl -pi -e 's|http://||;s/\./-/g;s|/|-|g'`
dumpFileLocal=$sdv.nt.gz

if [[ "$1" == "--help" ]]; then
   echo "usage: `basename $0` [--target] [-n]"
   echo ""
   echo "  Gather all versioned dataset dump files into one enormous dump file."
   echo "    archive them into a versioned dataset 'latest'"
   echo ""
   echo "         --target : return the dump file location, then quit."
   echo "               -n : perform dry run only; do not load named graph."
   echo
   exit 1
fi

if [ "$1" == "--target" ]; then
   # a conversion:VersionedDataset:
   # e.g. http://purl.org/twc/health/source/tw-rpi-edu/dataset/cr-publish-dcat-to-endpoint/version/2012-Sep-07
   echo $cockpit/publish/$dumpFileLocal
   exit 0
fi

dryrun="false"
if [ "$1" == "-n" ]; then
   dryrun="true"
   dryrun.sh $dryrun beginning
   shift
fi

for panel in 'source' 'automatic' 'publish'; do
   if [ ! -d $cockpit/$panel ]; then
      mkdir -p $cockpit/$panel
   fi
   echo "rm -rf $cockpit/$panel/*"
   if [ "$dryrun" != "true" ]; then
      rm -rf $cockpit/$panel/*
   fi
done

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Collect source files into source/
if [ "$dryrun" != "true" ]; then
   for datadump in `cr-list-versioned-dataset-dumps.sh --warn-if-missing`; do
      echo ln $datadump $cockpit/source/
      if [ "$dryrun" != "true" ]; then
         ln $datadump $cockpit/source/
      fi
   done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Build up full dump file into publish/
if [[ -n "`getconf ARG_MAX`" && \
     `find $cockpit/source -name "*.*" | wc -l` -lt `getconf ARG_MAX` ]]; then
   # Saves disk space, but shell can't handle infinite arguments.
   echo "rdf2nt.sh --version 2 'find $cockpit/source' | gzip 2> $cockpit/publish/rdf2nt-errors.log LT $cockpit/publish/$dumpFileLocal"
   #if [ "$dryrun" != "true" ]; then
      rdf2nt.sh --version 2 `find $cockpit/source` 2> $cockpit/publish/rdf2nt-errors.log | gzip > $cockpit/publish/$dumpFileLocal 2> $cockpit/publish/gzip-errors.log
   #fi
else
   # Handles infinite source/* files, but uses disk space.
   for datadump in `find $cockpit/source`; do
      echo "rdf2nt.sh --version 2 $datadump APPEND $cockpit/publish/$dumpFileLocal.tmp"
      if [ "$dryrun" != "true" ]; then
         rdf2nt.sh --version 2 $datadump >> $cockpit/publish/$dumpFileLocal.tmp
      fi
   done
   if [ "$dryrun" != "true" ]; then
      cat $cockpit/publish/$dumpFileLocal.tmp | gzip > $cockpit/publish/$dumpFileLocal
      rm $cockpit/publish/$dumpFileLocal.tmp
   fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Pull out the RDF URI nodes from the full dump.
echo

echo $cockpit/automatic/$sdv-uri-node-occurrences.txt
uri-nodes.sh $cockpit/publish/$dumpFileLocal                              > $cockpit/automatic/$sdv-uri-node-occurrences.txt

# no space left on device...
# echo $cockpit/automatic/$sdv-uri-node-occurrences-sorted.txt
# cat          $cockpit/automatic/$sdv-uri-node-occurrences.txt | sort    > $cockpit/automatic/$sdv-uri-node-occurrences-sorted.txt

echo $cockpit/automatic/$sdv-uri-nodes.txt
cat          $cockpit/automatic/$sdv-uri-node-occurrences.txt   | sort -u > $cockpit/automatic/$sdv-uri-nodes.txt

echo $cockpit/publish/$sdv-uri-nodes.ttl
echo "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."                    > $cockpit/publish/$sdv-uri-nodes.ttl
echo                                                                             >> $cockpit/publish/$sdv-uri-nodes.ttl
cat $cockpit/automatic/$sdv-uri-nodes.txt | awk '{print $1,"a rdfs:Resource ."}' >> $cockpit/publish/$sdv-uri-nodes.ttl
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

dryrun.sh $dryrun ending
