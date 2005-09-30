/*
 *      $Id$
 */
/************************************************************************
*									*
*			     Copyright (C)  2002			*
*				Internet2				*
*			     All Rights Reserved			*
*									*
************************************************************************/
/*
 *	File:		powstreamP.h
 *
 *	Author:		Jeff Boote
 *			Internet2
 *
 *	Date:		Tue Sep  3 15:44:17 MDT 2002
 *
 *	Description:	
 */
#ifndef	_powstreamp_h_
#define	_powstreamp_h_

#include <I2util/table.h>

/*
 * Bound of the RTT in seconds. This application needs an estimate of how
 * long it takes to request a test session. It uses this estimate to make
 * sure that it has enough time to make the test requests before those
 * tests actually need to start. (It times the first connection to get
 * a good idea, but does not dynamically modifiy the number of sessions
 * per series based on changes to the RTT over time.) This constant
 * is used to bound that estimate. i.e. we hope that the RTT never gets
 * worse then this value, or the initial value retrieved dynamically.
 * If the RTT gets worse than this, there will be breaks between the
 * sessions.
 */
#define	SETUP_ESTIMATE	10

/*
 * Lock file name. This file is created in the output directory to ensure
 * there is not more than one powstream process writing there.
 */
#define	POWLOCK	".powlock"
#define	POWTMPFILEFMT	"pow.XXXXXX"
#define INCOMPLETE_EXT	".i"
#define SUMMARY_EXT	".sum"

/*
 * Reasonable limits on these so dynamic memory is not needed.
 */
#define	MAX_PASSPROMPT	256
#define	MAX_PASSPHRASE	256

/*
 * Application "context" structure
 */
typedef	struct {
	/*
	**	Command line options
	*/
	struct  {
		/* Flags */

		char		*srcaddr;         /* -S */
		char		*authmode;        /* -A */
		char		*identity;        /* -u */
		char		*keyfile;          /* -k */

#ifndef	NDEBUG
		I2Boolean	childwait;        /* -w */
#endif

		u_int32_t	numSessPackets;       /* -C */
		u_int32_t	numFilePackets;       /* -c */
		u_int32_t	numSumPackets;       /* -N */
		double		lossThreshold;    /* -L (seconds) */
		double		meanWait;        /* -i  (seconds) */
		u_int32_t	padding;          /* -s */

		char		*savedir;	/* -d */
		I2Boolean	printfiles;	/* -p */
		int		facility;	/* -e */
		I2Boolean	verbose;	/* -r stderr too */
		double		bucketWidth;	/* -b (seconds) */

	} opt;

	char			*remote_test;
	char			*remote_serv;

	u_int32_t		auth_mode;

	OWPContext		lib_ctx;

} powapp_trec, *powapp_t;

typedef struct pow_cntrl_rec{
	OWPControl		cntrl;
	OWPScheduleContext	sctx;
	OWPSID			sid;
	OWPNum64		*sessionStart;
	OWPNum64		owptime_mem;
	FILE			*fp;
	FILE			*testfp;
	char			fname[PATH_MAX];
	u_int32_t		numPackets;
} pow_cntrl_rec, *pow_cntrl;

typedef struct pow_seen_rec{
	OWPNum64	sendtime;	/* presumed send time. */
	u_int32_t	seen;
} pow_seen_rec, *pow_seen;

struct pow_parse_rec{
        /* parse state */
	OWPContext		ctx;

        OWPBoolean              do_subfile;

        /* file offsets for parsing */
	off_t			begin;
	off_t			next;

        /* "real" seq_no's for first/last in this {sub,sum}session */
	u_int32_t		first;
	u_int32_t		last;

	u_int32_t		i;  /* current record index into file */
	u_int32_t		n;  /* number of records counted/written */

	pow_seen		seen; /* index is in sub-session space */


        /* sub-session fields */
	FILE			*fp;	/* sub-session data file	*/
	OWPSessionHeader	hdr;
	OWPTimeStamp		missing;/* used to hold err est		*/

        /* Summary fields */
	FILE			*sfp;	/* summary file			*/
	I2Table			buckets;
	u_int32_t		*bucketvals;
	u_int32_t		nbuckets;
	I2Boolean		bucketerror;
	double			maxerr;
	u_int32_t		sync;
	u_int32_t		dups;
	u_int32_t		lost;
	double			min_delay;
	double			max_delay;
};
#endif
