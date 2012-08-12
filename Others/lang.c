/* $Id: lang.h,v 1.1 2004/08/02 07:19:05 titer Exp $

   This file is part of the HandBrake source code.
   Homepage: <http://handbrake.fr/>.
   It may be used under the terms of the GNU General Public License. */

#include "lang.h"
#include <string.h>
#include <ctype.h>

static const iso639_lang_t languages[] =
{ { "Unknown", "", "", "und", "", 32767 },
  { "Afar", "", "aa", "﻿aar", "", -1 },
  { "Abkhazian", "", "ab", "abk", "", -1 },
  { "Achinese", "", "", "ace", "", -1 },
  { "Acoli", "", "", "ach", "", -1 },
  { "Adangme", "", "", "ada", "", -1 },
  { "Adygei", "", "", "ady", "", -1 },
  { "Afroasiatic languages", "", "", "afa", "", -1 },
  { "Afrihili", "", "", "afh", "", -1 },
  { "Afrikaans", "", "af", "afr", "", 141 },
  { "Ainu", "", "", "ain", "", -1 },
  { "Akan", "", "ak", "aka", "", -1 },
  { "Akkadian", "", "", "akk", "", -1 },
  { "Albanian", "", "sq", "sqi", "alb", 36 },
  { "Amharic", "", "am", "amh", "", 85 },
  { "Arabic", "", "ar", "ara", "", 12 },
  { "Aragonese", "", "an", "arg", "", -1 },
  { "Armenian", "", "hy", "hye", "arm", 51 },
  { "Assamese", "", "as", "asm", "", 68 },
  { "Avaric", "", "av", "ava", "", -1 },
  { "Avestan", "", "ae", "ave", "", -1 },
  { "Aymara", "", "ay", "aym", "", 134 },
  { "Azerbaijani", "", "az", "aze", "", 49 },
  { "Bashkir", "", "ba", "bak", "", -1 },
  { "Bambara", "", "bm", "bam", "", -1 },
  { "Basque", "", "eu", "eus", "baq", 129 },
  { "Belarusian", "", "be", "bel", "", -1 },
  { "Bengali", "", "bn", "ben", "", 67 },
  { "Bihari", "", "bh", "bih", "", -1 },
  { "Bislama", "", "bi", "bis", "", -1 },
  { "Bosnian", "", "bs", "bos", "", -1 },
  { "Breton", "", "br", "bre", "", 142 },
  { "Bulgarian", "", "bg", "bul", "", 44 },
  { "Burmese", "", "my", "mya", "bur", 77 },
  { "Catalan", "", "ca", "cat", "", 130 },
  { "Chamorro", "", "ch", "cha", "", -1 },
  { "Chechen", "", "ce", "che", "", -1 },
  { "Chinese", "", "zh", "zho", "chi", 19 },
  { "Church Slavic", "", "cu", "chu", "", -1 },
  { "Chuvash", "", "cv", "chv", "", -1 },
  { "Cornish", "", "kw", "cor", "", -1 },
  { "Corsican", "", "co", "cos", "", -1 },
  { "Cree", "", "cr", "cre", "", -1 },
  { "Czech", "", "cs", "ces", "cze", 38 },
  { "Danish", "Dansk", "da", "dan", "", 7 },
  { "Divehi", "", "dv", "div", "", -1 },
  { "Dutch", "Nederlands", "nl", "nld", "dut", 4 },
  { "Dzongkha", "", "dz", "dzo", "", 137 },
  { "English", "English", "en", "eng", "", 0 },
  { "Esperanto", "", "eo", "epo", "", 94 },
  { "Estonian", "", "et", "est", "", 27 },
  { "Ewe", "", "ee", "ewe", "", -1 },
  { "Faroese", "", "fo", "fao", "", 30 },
  { "Fijian", "", "fj", "fij", "", -1 },
  { "Finnish", "Suomi", "fi", "fin", "", 13 },
  { "French", "Francais", "fr", "fra", "fre", 1 },
  { "Western Frisian", "", "fy", "fry", "", -1 },
  { "Fulah", "", "ff", "ful", "", -1 },
  { "Georgian", "", "ka", "kat", "geo", 52 },
  { "German", "Deutsch", "de", "deu", "ger", 2 },
  { "Gaelic (Scots)", "", "gd", "gla", "", 144 },
  { "Irish", "", "ga", "gle", "", 35 },
  { "Galician", "", "gl", "glg", "", 140 },
  { "Manx", "", "gv", "glv", "", -1 },
  { "Greek, Modern", "", "el", "ell", "gre", 14 },
  { "Guarani", "", "gn", "grn", "", 133 },
  { "Gujarati", "", "gu", "guj", "", 69 },
  { "Haitian", "", "ht", "hat", "", -1 },
  { "Hausa", "", "ha", "hau", "", -1 },
  { "Hebrew", "", "he", "heb", "", 10 },
  { "Herero", "", "hz", "her", "", -1 },
  { "Hindi", "", "hi", "hin", "", 21 },
  { "Hiri Motu", "", "ho", "hmo", "", -1 },
  { "Hungarian", "Magyar", "hu", "hun", "", 26 },
  { "Igbo", "", "ig", "ibo", "", -1 },
  { "Icelandic", "Islenska", "is", "isl", "ice", 15 },
  { "Ido", "", "io", "ido", "", -1 },
  { "Sichuan Yi", "", "ii", "iii", "", -1 },
  { "Inuktitut", "", "iu", "iku", "", 143 },
  { "Interlingue", "", "ie", "ile", "", -1 },
  { "Interlingua", "", "ia", "ina", "", -1 },
  { "Indonesian", "", "id", "ind", "", 81 },
  { "Inupiaq", "", "ik", "ipk", "", -1 },
  { "Italian", "Italiano", "it", "ita", "", 3 },
  { "Javanese", "", "jv", "jav", "", 138 },
  { "Japanese", "", "ja", "jpn", "", 11 },
  { "Kalaallisut (Greenlandic)", "", "kl", "kal", "", 194 },
  { "Kannada", "", "kn", "kan", "", 73 },
  { "Kashmiri", "", "ks", "kas", "", 61 },
  { "Kanuri", "", "kr", "kau", "", -1 },
  { "Kazakh", "", "kk", "kaz", "", 48 },
  { "Central Khmer", "", "km", "khm", "", 78 },
  { "Kikuyu", "", "ki", "kik", "", -1 },
  { "Kinyarwanda", "", "rw", "kin", "", 90 },
  { "Kirghiz", "", "ky", "kir", "", 54 },
  { "Klingon", "", "", "tlh", "", -1 },
  { "Komi", "", "kv", "kom", "", -1 },
  { "Kongo", "", "kg", "kon", "", -1 },
  { "Korean", "", "ko", "kor", "", 23 },
  { "Kuanyama", "", "kj", "kua", "", -1 },
  { "Kurdish", "", "ku", "kur", "", 60 },
  { "Lao", "", "lo", "lao", "", 79 },
  { "Latin", "", "la", "lat", "", 131 },
  { "Latvian", "", "lv", "lav", "", 28 },
  { "Limburgan", "", "li", "lim", "", -1 },
  { "Lingala", "", "ln", "lin", "", -1 },
  { "Lithuanian", "", "lt", "lit", "", 24 },
  { "Luxembourgish", "", "lb", "ltz", "", -1 },
  { "Luba-Katanga", "", "lu", "lub", "", -1 },
  { "Ganda", "", "lg", "lug", "", -1 },
  { "Macedonian", "", "mk", "mkd", "mac", 43 },
  { "Marshallese", "", "mh", "mah", "", -1 },
  { "Malayalam", "", "ml", "mal", "", 72 },
  { "Maori", "", "mi", "mri", "mao", -1 },
  { "Marathi", "", "mr", "mar", "", 66 },
  { "Malay", "", "ms", "msa", "msa", -1 },
  { "Malagasy", "", "mg", "mlg", "", 93 },
  { "Maltese", "", "mt", "mlt", "", 16 },
  { "Moldavian", "", "mo", "mol", "", 53 },
  { "Mongolian", "", "mn", "mon", "", 57 },
  { "Nauru", "", "na", "nau", "", -1 },
  { "Navajo", "", "nv", "nav", "", -1 },
  { "Ndebele, South", "", "nr", "nbl", "", -1 },
  { "Ndebele, North", "", "nd", "nde", "", -1 },
  { "Ndonga", "", "ng", "ndo", "", -1 },
  { "Nepali", "", "ne", "nep", "", 64 },
  { "Norwegian Nynorsk", "", "nn", "nno", "", 151 },
  { "Norwegian Bokmål", "", "nb", "nob", "", 9 },
  { "Norwegian", "Norsk", "no", "nor", "", 9 },
  { "Chichewa; Nyanja", "", "ny", "nya", "", 92 },
  { "Occitan (post 1500); Provençal", "", "oc", "oci", "", -1 },
  { "Ojibwa", "", "oj", "oji", "", -1 },
  { "Oriya", "", "or", "ori", "", 71 },
  { "Oromo", "", "om", "orm", "", 87 },
  { "Ossetian; Ossetic", "", "os", "oss", "", -1 },
  { "Panjabi", "", "pa", "pan", "", 70 },
  { "Persian", "", "fa", "fas", "per", 31 },
  { "Pali", "", "pi", "pli", "", -1 },
  { "Polish", "", "pl", "pol", "", 25 },
  { "Portuguese", "Portugues", "pt", "por", "", 8 },
  { "Pushto", "", "ps", "pus", "", -1 },
  { "Quechua", "", "qu", "que", "", 132 },
  { "Romansh", "", "rm", "roh", "", -1 },
  { "Romanian", "", "ro", "ron", "rum", 37 },
  { "Rundi", "", "rn", "run", "", 91 },
  { "Russian", "", "ru", "rus", "", 32 },
  { "Sango", "", "sg", "sag", "", -1 },
  { "Sanskrit", "", "sa", "san", "", 65 },
  { "Serbian", "", "sr", "srp", "scc", 42 },
  { "Croatian", "Hrvatski", "hr", "hrv", "scr", 18 },
  { "Sinhala", "", "si", "sin", "", 76 },
  { "Slovak", "", "sk", "slk", "slo", 39 },
  { "Slovenian", "", "sl", "slv", "", 40 },
  { "Northern Sami", "", "se", "sme", "", 29 },
  { "Samoan", "", "sm", "smo", "", -1 },
  { "Shona", "", "sn", "sna", "", -1 },
  { "Sindhi", "", "sd", "snd", "", 62 },
  { "Somali", "", "so", "som", "", 88 },
  { "Sotho, Southern", "", "st", "sot", "", -1 },
  { "Spanish", "Espanol", "es", "spa", "", 6 },
  { "Sardinian", "", "sc", "srd", "", -1 },
  { "Swati", "", "ss", "ssw", "", -1 },
  { "Sundanese", "", "su", "sun", "", 139 },
  { "Swahili", "", "sw", "swa", "", 89 },
  { "Swedish", "Svenska", "sv", "swe", "", 5 },
  { "Tahitian", "", "ty", "tah", "", -1 },
  { "Tamil", "", "ta", "tam", "", 74 },
  { "Tatar", "", "tt", "tat", "", 135 },
  { "Telugu", "", "te", "tel", "", 75 },
  { "Tajik", "", "tg", "tgk", "", 55 },
  { "Tagalog", "", "tl", "tgl", "", 82 },
  { "Thai", "", "th", "tha", "", 22 },
  { "Tibetan", "", "bo", "bod", "tib", 63 },
  { "Tigrinya", "", "ti", "tir", "", 86 },
  { "Tonga (Tonga Islands)", "", "to", "ton", "", 147 },
  { "Tswana", "", "tn", "tsn", "", -1 },
  { "Tsonga", "", "ts", "tso", "", -1 },
  { "Turkmen", "", "tk", "tuk", "", 56 },
  { "Turkish", "", "tr", "tur", "", 17 },
  { "Twi", "", "tw", "twi", "", -1 },
  { "Uighur", "", "ug", "uig", "", 136 },
  { "Ukrainian", "", "uk", "ukr", "", 45 },
  { "Urdu", "", "ur", "urd", "", 20 },
  { "Uzbek", "", "uz", "uzb", "", 47 },
  { "Venda", "", "ve", "ven", "", -1 },
  { "Vietnamese", "", "vi", "vie", "", 80 },
  { "Volapük", "", "vo", "vol", "", -1 },
  { "Welsh", "", "cy", "cym", "wel", 128 },
  { "Walloon", "", "wa", "wln", "", -1 },
  { "Wolof", "", "wo", "wol", "", -1 },
  { "Xhosa", "", "xh", "xho", "", -1 },
  { "Yiddish", "", "yi", "yid" , "", 41 },
  { "Yoruba", "", "yo", "yor", "", -1 },
  { "Zhuang", "", "za", "zha", "", -1 },
  { "Zulu", "", "zu", "zul", "", -1 },
  { NULL, NULL, NULL, NULL, NULL, -1 } };

iso639_lang_t * lang_for_code( int code )
{
    char code_string[2];
    iso639_lang_t * lang;

    code_string[0] = tolower( ( code >> 8 ) & 0xFF );
    code_string[1] = tolower( code & 0xFF );

    for( lang = (iso639_lang_t*) languages; lang->eng_name; lang++ )
    {
        if( !strncmp( lang->iso639_1, code_string, 2 ) )
        {
            return lang;
        }
    }

    return (iso639_lang_t*) languages;
}

iso639_lang_t * lang_for_code2( const char *code )
{
    char code_string[4];
    iso639_lang_t * lang;

    code_string[0] = tolower( code[0] );
    code_string[1] = tolower( code[1] );
    code_string[2] = tolower( code[2] );
    code_string[3] = 0;

    for( lang = (iso639_lang_t*) languages; lang->eng_name; lang++ )
    {
        if( !strcmp( lang->iso639_2, code_string ) )
        {
            return lang;
        }
        if( lang->iso639_2b && !strcmp( lang->iso639_2b, code_string ) )
        {
            return lang;
        }
    }

    return (iso639_lang_t*) languages;
}

iso639_lang_t * lang_for_qtcode( short code )
{
    iso639_lang_t * lang;

    for( lang = (iso639_lang_t*) languages; lang->eng_name; lang++ )
    {
        if( lang->qtLang == code )
        {
            return lang;
        }
    }
    
    return (iso639_lang_t*) languages;
}

int lang_to_code(const iso639_lang_t *lang)
{
    int code = 0;

    if (lang)
        code = (lang->iso639_1[0] << 8) | lang->iso639_1[1];

    return code;
}

iso639_lang_t * lang_for_english( const char * english )
{
    iso639_lang_t * lang;

    for( lang = (iso639_lang_t*) languages; lang->eng_name; lang++ )
    {
        if( !strcmp( lang->eng_name, english ) )
        {
            return lang;
        }
    }

    return (iso639_lang_t*) languages;
}

