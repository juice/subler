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

t = tvdb_api.Tvdb(apikey = "3498815BE9484A62", banners=True, actors=True)
d = dict()
d['episodes'] = list()
d['actors'] = list()
d['artwork_posters'] = list()
d['artwork_series'] = list()
d['artwork_season'] = list()

if len(sys.argv) >= 2:

	seriesName = sys.argv[1]
	seasonNum = -1

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

		for actorNum in range(len(t[seriesName]['_actors'])):
			d['actors'].append(t[seriesName]['_actors'][actorNum]['name'])

		for bannerID in t[seriesName]['_banners']['poster']['680x1000'].iterkeys():
			d['artwork_posters'].append(t[seriesName]['_banners']['poster']['680x1000'][bannerID]['_bannerpath'])
		for bannerID in t[seriesName]['_banners']['series']['graphical'].iterkeys():
			if (t[seriesName]['_banners']['series']['graphical'][bannerID]['language'] == 'en'):
				d['artwork_series'].append(t[seriesName]['_banners']['series']['graphical'][bannerID]['_bannerpath'])
		for bannerID in t[seriesName]['_banners']['series']['text'].iterkeys():
			if (t[seriesName]['_banners']['series']['text'][bannerID]['language'] == 'en'):
				d['artwork_series'].append(t[seriesName]['_banners']['series']['text'][bannerID]['_bannerpath'])
		if (seasonNum >= 0):
			for bannerID in t[seriesName]['_banners']['season']['season'].iterkeys():
				if (int(t[seriesName]['_banners']['season']['season'][bannerID]['season']) is seasonNum):
					if (t[seriesName]['_banners']['season']['season'][bannerID]['language'] == 'en'):
						d['artwork_season'].append(t[seriesName]['_banners']['season']['season'][bannerID]['_bannerpath'])
			


	except tvdb_exceptions.tvdb_exception:
		d['seriesname'] = ''

	finally:
		f = tempfile.mkstemp()
		fn = f[1]
		os.close(f[0])
		plistlib.writePlist(d, fn)
		print fn
