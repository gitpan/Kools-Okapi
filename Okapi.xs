/*
 *  This file is part of the Kools::Okapi package
 *  a Perl C wrapper for the Thomson Reuters Kondor+ OKAPI api.
 *
 *  Copyright (C) 2009 Gabriel Galibourg
 *
 *  The Kools::Okapi package is free software; you can redistribute it and/or
 *  modify it under the terms of the Artistic License 2.0 as published by
 *  The Perl Foundation; either version 2.0 of the License, or
 *  (at your option) any later version.
 *
 *  The Kools::Okapi package is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  Perl Artistic License for more details.
 *
 *  You should have received a copy of the Artistic License along with
 *  this package.  If not, see <http://www.perlfoundation.org/legal/>.
 *
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "okapi.h"


typedef struct {
    ICC_opaque   iccObj;
    long         clientData;

    SV*          data_msg_callback;
    SV*          set_fds_callback;
    SV*          select_timeout_callback;
    SV*          select_signal_callback;
    SV*          select_msg_callback;
    SV*          disconnect_callback;
    SV*          reconnect_callback;
}  perl_iccObj_t;




/* ================================
 *
 * _data_msg_callback
 *
 * Generic callback registered for ICC_DATA_MSG_CALLBACK events.
 */
static ICC_status_t
_data_msg_callback(ICC_opaque cd, char *key, ICC_Data_Msg_Type_t type)
{
    perl_iccObj_t *picc=(perl_iccObj_t*)cd;
    dSP;

    int count;
    int retval;
    
    
    ENTER;SAVETMPS;
    PUSHMARK(SP);
    XPUSHs (sv_2mortal (newSViv ( cd)));
    XPUSHs (sv_2mortal (newSVpv ( key, strlen(key))));
    XPUSHs (sv_2mortal (newSViv ( type  )));
    PUTBACK;

    count = call_sv(picc->data_msg_callback, G_SCALAR);
    SPAGAIN;

    if ( count!= 1 )
        croak ("icc_data_callback() returned more than one argument\n");

    retval = POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;
    return retval;
}

/* ================================
 *
 * _select _timeout_callback
 *
 * Generic callback registered for ICC_SELECT_TIMEOUT_CALLBACK events.
 */
static ICC_status_t
_select_timeout_callback(ICC_opaque cd)
{
    perl_iccObj_t *picc=(perl_iccObj_t*)cd;
    dSP;

    int count;
    int retval;
    
    
    ENTER;SAVETMPS;
    PUSHMARK(SP);
    XPUSHs (sv_2mortal (newSViv ( cd)));
    PUTBACK;

    count = call_sv(picc->select_timeout_callback, G_SCALAR);
    SPAGAIN;

    if ( count!= 1 )
        croak ("icc_select_timeout_callback() returned more than one argument\n");

    retval = POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;
    return retval;
}


int
process_createAndSetParameters(perl_iccObj_t *picc, int key, SV* attrib, SV* attrib2, SV* attrib3)
{
    int skipStack=1; // default is just one parameter to take off the stack
    
    printf("key=%d  attrib=%ld\n",key,attrib);
    switch (key) {
        // these attributes do not take any parameter
        case ICC_DISCONNECT:
            skipStack=0;
            break;

        // these attributes take integer values
        case ICC_TIMEOUT:
        case ICC_RECONNECT:
        case ICC_PING_INTERVAL:
        case ICC_CLIENT_READY:
        case ICC_SELECT_TIMEOUT:
            {
                long val=SvIV(attrib);
                printf("%d(INT): %d\n",key,val);
                if (ICC_OK != ICC_set(picc->iccObj,key,val,NULL,NULL))
                    croak("ICC_set(%d,%d) failed ...\n",key,val);
            }
            break;

        // these attributes take strings
        case ICC_PORT_NAME:
        case ICC_KIS_HOST_NAMES:
        case ICC_CLIENT_NAME:
        case ICC_CRYPT_PASSWORD:
           {
               STRLEN l;
               char *val=(char*)SvPV(attrib,l);
               printf("%d(STR): %s\n",key,val);
               if (ICC_OK != ICC_set(picc->iccObj,key,val,NULL,NULL))
                    croak("ICC_set(%d,%s) failed ...\n",key,val);
            }
            break;

        // a long (pointer, etc...)
        case ICC_CLIENT_DATA:
            {
                long l=(long)SvIV(attrib);
                picc->clientData=l;
            }
            break;

        // takes an array of strings
        case ICC_CLIENT_RECEIVE_ARRAY:
            {
                char *fn;
                STRLEN l;
                I32 n, numStr=av_len((AV*)SvRV(attrib));
                char *ar[100];
                for (n=0 ; n<=numStr && n<=96 ; ++n) {
                    fn=SvPV(*av_fetch((AV*)SvRV(attrib),n,0),l);
                    ar[n]=strdup(fn);
                }
                ar[n+0]=NULL;
                ar[n+1]=NULL;
                        
                if (ICC_OK != ICC_set(picc->iccObj,ICC_CLIENT_RECEIVE,
                                      ar[ 0],ar[ 1],ar[ 2],ar[ 3],ar[ 4],
                                      ar[ 5],ar[ 6],ar[ 7],ar[ 8],ar[ 9],
                                      ar[10],ar[11],ar[12],ar[13],ar[14],
                                      ar[15],ar[16],ar[17],ar[18],ar[19],
                                      NULL,NULL)) {
                    croak("ICC_set(ICC_CLIENT_RECEIVE,....) failed\n");
                }
            }
            break;

        // callbacks
        case ICC_DATA_MSG_CALLBACK:
            if (ICC_OK != ICC_set(picc->iccObj,key,_data_msg_callback,NULL))
                croak("ICC_set(ICC_DATA_MSG_CALLBACK,....) failed\n");
            sv_setsv (picc->data_msg_callback, attrib);
            break;
                     
        case ICC_SET_FDS_CALLBACK: //TODO
            break;
        case ICC_SELECT_TIMEOUT_CALLBACK:
            if (ICC_OK != ICC_set(picc->iccObj,key,_select_timeout_callback,NULL))
                croak("ICC_set(ICC_SELECT_TIMEOUT_CALLBACK,....) failed\n");
            sv_setsv (picc->select_timeout_callback, attrib);
            break;
        
        case ICC_SELECT_SIGNAL_CALLBACK: //TODO
        case ICC_SELECT_MSG_CALLBACK: //TODO
        case ICC_DISCONNECT_CALLBACK: //TODO
        case ICC_RECONNECT_CALLBACK: //TODO
            break;

        // send data to server
        case ICC_SEND_DATA:
            {
                STRLEN l;
                char *keyStr=SvPV(attrib,l);
                int type=SvIV(attrib2);
                char *buf=SvPV(attrib3,l);
                if (ICC_OK != ICC_set(picc->iccObj,key,keyStr,type,buf,NULL)) {
                    croak("ICC_set(ICC_SEND_DATA,...) failed\n");
                }
                skipStack=3;
            }
            break;

        // specific errors:
        case ICC_CLIENT_RECEIVE:
            croak("ICC_set: use ICC_CLIENT_RECEIVE_ARRAY instead of ICC_CLIENT_RECEIVE!\n");
            break;

        default:
            croak("ICC_set internal error: %d is unknown!\n",key);
    } // end switch
    
    return skipStack;
}


MODULE = Kools::Okapi        PACKAGE = Kools::Okapi


perl_iccObj_t *
ICC_create(fArg,...)
    ICC_option_t fArg = NO_INIT
    CODE:
        ICC_opaque iccObj;
        int i=0;
        perl_iccObj_t *picc;

        // perform ICC_create, if it fails bail out.        
        iccObj=ICC_create(0);
        if (0L==iccObj)
            croak("ICC_create(NULL) failed\n");
        
        // now allocate main Perl ICC structure
        picc=calloc(sizeof(perl_iccObj_t),1);
        if (NULL==picc)
            croak("Out of memory in ICC_create()\n");
            
        // fill up picc
        picc->iccObj=iccObj;
        picc->data_msg_callback        = newSVsv (&PL_sv_undef);
        picc->set_fds_callback         = newSVsv (&PL_sv_undef);
        picc->select_timeout_callback  = newSVsv (&PL_sv_undef);
        picc->select_signal_callback   = newSVsv (&PL_sv_undef);
        picc->select_msg_callback      = newSVsv (&PL_sv_undef);
        picc->disconnect_callback      = newSVsv (&PL_sv_undef);
        picc->reconnect_callback       = newSVsv (&PL_sv_undef);


        if (ICC_OK != ICC_set(iccObj,ICC_CLIENT_DATA,picc,NULL))
            croak("ICC_create(internal ICC_CLIENT_DATA) failed\n");
        
        while (i<items) {
            ICC_option_t key=SvIV(ST(i));
            SV* p1 = (i+1<items ? ST(i+1) : NULL);
            SV* p2 = (i+2<items ? ST(i+2) : NULL);
            SV* p3 = (i+3<items ? ST(i+3) : NULL);
            int iSkip=process_createAndSetParameters(picc, key,p1,p2,p3);
            i += iSkip+1;
        }
        RETVAL = picc;
    OUTPUT:
        RETVAL


ICC_status_t
ICC_set(picc,fArg,...)
    perl_iccObj_t* picc
    ICC_option_t fArg = NO_INIT
    CODE:
        ICC_status_t status;
        int i=1;

        while (i<items) {
            ICC_option_t key=SvIV(ST(i));
            SV* p1 = (i+1<items ? ST(i+1) : NULL);
            SV* p2 = (i+2<items ? ST(i+2) : NULL);
            SV* p3 = (i+3<items ? ST(i+3) : NULL);
            int iSkip=process_createAndSetParameters(picc, key,p1,p2,p3);
            i += iSkip+1;
        }
        RETVAL = ICC_OK;
    OUTPUT:
        RETVAL


SV*
ICC_get(picc,attrib)
    perl_iccObj_t* picc
    ICC_option_t attrib
    CODE:
        RETVAL=newSV(0);
        switch (attrib) {
            // these attributes take strings
            case ICC_PORT_NAME:
            case ICC_KIS_HOST_NAMES:
            case ICC_CLIENT_NAME:
            case ICC_CRYPT_PASSWORD:
            case ICC_GET_SENT_DATA_MSG_FOR_DISPLAY:
                {
                    char *s=(char*)ICC_get(picc->iccObj,attrib);
                    if (s!=NULL)
                        sv_setpv(RETVAL,s);
                }
                break;

            // these attributes take integer values
            case ICC_TIMEOUT:
            case ICC_RECONNECT:
            case ICC_PING_INTERVAL:
            case ICC_CLIENT_READY:
            case ICC_SELECT_TIMEOUT:
            default:
                {
                    long l=(long)ICC_get(picc->iccObj,attrib);
                    sv_setiv(RETVAL,l);
                }
                break;
        }
    OUTPUT:
        RETVAL


ICC_status_t
ICC_main_loop(picc)
    perl_iccObj_t* picc;
    CODE:
        RETVAL = ICC_main_loop(picc->iccObj);
    OUTPUT:
	    RETVAL


char *
ICC_DataMsg_Buffer_get()
    CODE:
        //RETVAL=newSV(0);
        RETVAL=ICC_DataMsg_Buffer_get();
        //if (buf!=NULL)
        //    sv_setpv(RETVAL,buf);
    OUTPUT:
        RETVAL


void
ICC_DataMsg_init(type, msgkey)
    ICC_Data_Msg_Type_t  type
    char *               msgkey


void
ICC_DataMsg_set(key, value)
    char *  key
    char *  value


void
ICC_DataMsg_Integer_set(key, value)
    char *  key
    int     value

char *
ICC_DataMsg_get(key)
    char *  key
    CODE:
        char *buf;
        int bufLen=0;
        long bufLenL=0;
        bufLenL=ICC_DataMsg_Size_find(key,&bufLen);
        if (bufLen>0) {
            char *buf=calloc(sizeof(char),bufLen+1);
            if (NULL==buf)
                croak("ICC_DataMsg_get() - out of memory\n");
            else {
                RETVAL=ICC_DataMsg_get(key,buf);
                free(buf);
            }
        }
        else
            RETVAL=NULL;
    OUTPUT:
        RETVAL

void
ICC_DataMsg_Buffer_set(buffer)
    char * buffer
    

int
ICC_DataMsg_send_to_server(picc)
    perl_iccObj_t * picc
    CODE:
        RETVAL=ICC_DataMsg_send_to_server(picc->iccObj);
    OUTPUT:
        RETVAL
    
