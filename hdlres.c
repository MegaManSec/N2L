/*
 * hdlres.c
 *
 * Very simple handle resolution client.
 *
 * Author: andy powell a.powell@ukoln.ac.uk
 *
 * $Id: hdlres.c,v 1.2 1998/04/28 12:23:19 lisap Exp $
 *
 * This code is based on hdl_res.c from the Handle Client Library distribution
 * which is...
*
*------------------------------------------------------------------------------
*             (c)  COPYRIGHT
*      Corporation for National Research Initiatives
*                Reston, Virginia
*******************************************************************************
 */

#include   <stdio.h>
#include   <ctype.h>
#include   "handle.h"
#include   "hdlproto.h"

#if defined(__STDC__)
int
main(int argc, char *argv[], char *envp[])
#else
int
main(argc, argv, envp)
int argc;
char *argv[];
char *envp[];
#endif
{
    char *handle;
    char input_line[256];
    char types_wanted_string[sizeof(input_line)];
    unsigned int *types_wanted = 0;
    int  i;
    int  list_is_complete;
    int  number_in_list;
    char *cptr;
    struct hdl_data_tuple *items;
    struct hdl_data_tuple *item_ptr;
    int retval, found_err;
    char *ret_err = 0;
    unsigned char *object_flag_bytes;
    unsigned int  num_object_flag_bytes;
    int redirect_handle_length;
    char *redirect_handle_server;
    short redirect_udp_port;
    short redirect_tcp_port;

    int  type_index = 0;


    handle = argv[1];
    list_is_complete = 0;
    number_in_list = 0;

       types_wanted = (unsigned int *)
                         realloc(types_wanted, 
                                 (number_in_list + 1) *
                                  sizeof(unsigned int));
       if (!types_wanted)
       {
          fprintf(stderr,
                   "Couldn't allocate memory to setup a data type request!\n");
	  exit(1);
       }
       else
       {
          *(types_wanted + number_in_list) = HDL_TYPE_URL;
       }
       types_wanted = (unsigned int *)
                         realloc(types_wanted, 
                                 (number_in_list + 1) *
                                  sizeof(unsigned int));
       if (!types_wanted)
       {
          fprintf(stderr,
                   "Couldn't allocate memory to setup a data type request!\n");
	  exit(1);
       }
       else
       {
          *(types_wanted + number_in_list) = HDL_TYPE_NULL;
       }

       items = (struct hdl_data_tuple *)NULL;
       object_flag_bytes= 0;
       num_object_flag_bytes = 10;
       redirect_handle_server=(char *)NULL;

       retval = hdl_get_data((unsigned char *)handle,
                                (long)strlen(handle),
                                types_wanted, (enum hdl_query_flags  *)NULL,
                                0L, 8500L, 
                                (char *)NULL, (short) -1, (short) 0, 
                                &items, 
                                &object_flag_bytes, &num_object_flag_bytes,
				&redirect_handle_server,
			        &redirect_handle_length,
		                &redirect_udp_port,
			        &redirect_tcp_port,
                                &ret_err);

       if (retval != 0)
       {
          if (ret_err)
             fprintf(stderr, "\nERROR: %d %s\n",retval, ret_err);
          else
             fprintf(stderr, "\nERROR: %d\n",retval);
	  exit(2);
       }
       else
       {
          /*
          *   First check out object flags.  This is kind of a hack,
          *   but I'm only going to check the first byte.
          */
          if (object_flag_bytes == 0)
          {
             fprintf(stderr, "No 'object flags' were returned.\n");
	    exit(1);
          }
          else
          {
           if (HDL_FLAG_VALUE(HDL_NUM_OBJECT_FLAGS, object_flag_bytes,
                                    HDL_DISABLED)) {
             fprintf(stderr, "%s\n", "The handle has been DISABLED.");
	    exit(1);
	   }
          }
   
          item_ptr = items;

          while (item_ptr != (struct hdl_data_tuple *)NULL)
          {
             switch (item_ptr->type)
             {
                case HDL_TYPE_URL:
                   for (i=0;i<item_ptr->value_length;i++)
                      putchar(item_ptr->value[i]);
                   printf("\n");
                   break;
             }
             item_ptr = item_ptr->next;
          }
       }
       hdl_destroy_list(items);
       free(object_flag_bytes);
}
