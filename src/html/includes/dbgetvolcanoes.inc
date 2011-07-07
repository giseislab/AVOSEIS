<?php
# Return a list of volcanoes from places db
# ex) $volcanoes = dbgetvolcanoes('/avort/devrun/places/volcanoes');
function dbgetvolcanoes($placesdb) {
	$db = ds_dbopen_table("$placesdb.places", "r");
	#$db = ds_dbopen_table('/usr/local/mosaic/AVO/internal/avoseis/dev/DATA/places/volcanoes.places', 'r');
	$nrecs = dbnrecs($db);
	#echo "got $nrecs records from $placesdb.places<br/>";
	for ($db[3]=0; $db[3]<$nrecs; $db[3]++) {
		$volcanoes[$db[3]] = dbgetv($db, "place");
	}
	sort($volcanoes);
  return $volcanoes;
}
?>
