#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "okapi.h"


typedef struct {
    ICC_opaque   iccObj;
    long         clientData;
    SV*          data_msg_callback;
    
}  perl_iccObj_t;


/*******************************/
/* Local Static Vars           */
/*******************************/
static SV *my_data_msg_callback; /* Pointer To Function for Registered Callback */


/******************************/
/* local callback             */
/******************************/
/* this function is called when the okapi dispatcher receives a message
   This function must be registered during initialisation.
*/
static ICC_status_t
_data_msg_callback(ICC_opaque io, char *key, ICC_Data_Msg_Type_t type)
{
    dSP;

    int count;
    int retval;
    
    
    ENTER;SAVETMPS;
    PUSHMARK(SP);
    XPUSHs (sv_2mortal (newSViv ( io)));
    XPUSHs (sv_2mortal (newSVpv ( key, strlen(key))));
    XPUSHs (sv_2mortal (newSViv ( type  )));
    PUTBACK;

    count = call_sv(my_data_msg_callback, G_SCALAR);
    SPAGAIN;

    if ( count!= 1 )
        croak ("perl-data_callback returned more than one argument\n");
    retval = POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;
    return retval;
}

int
printStack(perl_iccObj_t *picc, int key, SV* attrib)
{
    int skipStack=1;
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

        // callbacks TODO
        case ICC_DATA_MSG_CALLBACK:
            if (ICC_OK != ICC_set(picc->iccObj,key,_data_msg_callback,NULL))
                croak("ICC_set(ICC_DATA_MSG_CALLBACK,....) failed\n");
            sv_setsv (my_data_msg_callback, attrib);
            break;
                     
        case ICC_SET_FDS_CALLBACK:
        case ICC_SELECT_TIMEOUT_CALLBACK:
        case ICC_SELECT_SIGNAL_CALLBACK:
        case ICC_SELECT_MSG_CALLBACK:
        case ICC_DISCONNECT_CALLBACK:
        case ICC_RECONNECT_CALLBACK:
        case ICC_DOUBLECONN_CALLBACK:
            break;

        // specific errors:
        case ICC_CLIENT_RECEIVE:
            croak("ICC_create: use ICC_CLIENT_RECEIVE_ARRAY instead of ICC_CLIENT_RECEIVE!\n");
            break;
        case ICC_SEND_DATA:
            croak("ICC_create: ICC_SEND_DATA is not implemented\n");
            break;
        default:
            croak("ICC_create internal error: %d is unknown!\n",key);
    } // end switch
    
    return skipStack;
}


MODULE = Kools::Okapi        PACKAGE = Kools::Okapi

BOOT:
my_data_msg_callback = newSVsv (&PL_sv_undef);


perl_iccObj_t *
ICC_create(fArg,...)
    ICC_option_t fArg = NO_INIT
    CODE:
        ICC_opaque iccObj;
        perl_iccObj_t *picc=calloc(sizeof(perl_iccObj_t),1);
        
        iccObj=ICC_create(0);
        if (iccObj==0L) {
            free(picc);
            croak("ICC_create(NULL) failed\n");
        }
        picc->iccObj=iccObj;
        if (ICC_OK != ICC_set(iccObj,ICC_CLIENT_DATA,picc,NULL))
            croak("ICC_set(ICC_CLIENT_DATA) failed\n");
        
        int i=0;
        while (i<items) {
            ICC_option_t key=SvIV(ST(i));
            int iSkip=printStack(picc, key,ST(i+1));
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
            int iSkip=printStack(picc, key,ST(i+1));
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
        _data_msg_callback(picc,"Hello",1);
        RETVAL = ICC_main_loop(picc->iccObj);
    OUTPUT:
	    RETVAL


SV*
ICC_DataMsg_Buffer_get()
    CODE:
        RETVAL=newSV(0);
        char *buf=ICC_DataMsg_Buffer_get();
        if (buf!=NULL)
            sv_setpv(RETVAL,buf);
    OUTPUT:
        RETVAL


