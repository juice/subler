#!/usr/bin/env python
#encoding:utf-8
#author:Douglas Stebila
#license:Creative Commons GNU GPL v2
# (http://creativecommons.org/licenses/GPL/2.0/)

import os
import plistlib
import sys
import tempfile
import tvdb_api
import tvdb_exceptions

def cleanDict(d):
	for k in d.iterkeys():
			if d[k] is None:
				d[k] = ""

t = tvdb_api.Tvdb(apikey = "3498815BE9484A62")
d = dict()
d['episodes'] = list()

if len(sys.argv) >= 2:

	seriesName = sys.argv[1]

	try:

		if len(sys.argv) is 2:
			for seasonNum in t[seriesName].iterkeys():
				for episodeNum in t[seriesName][seasonNum].iterkeys():
					e = dict(t[seriesName][seasonNum][episodeNum])
					cleanDict(e)
					d['episodes'].append(e)

		if len(sys.argv) is 3:
			seasonNum  = int(sys.argv[2])
			for episodeNum in t[seriesName][seasonNum].iterkeys():
				e = dict(t[seriesName][seasonNum][episodeNum])
				cleanDict(e)
				d['episodes'].append(e)

		if len(sys.argv) is 4:
			seasonNum  = int(sys.argv[2])
			episodeNum = int(sys.argv[3])
			e = dict(t[seriesName][seasonNum][episodeNum])
			cleanDict(e)
			d['episodes'].append(e)

		d['seriesname'] = t[seriesName]['seriesname']

	except tvdb_exceptions.tvdb_exception:
		d['seriesname'] = ''

	finally:
		f = tempfile.mkstemp()
		fn = f[1]
		os.close(f[0])
		plistlib.writePlist(d, fn)
		print fn
