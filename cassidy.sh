#!/bin/sh
#	Cassidy 
#	-  A blogging system.
#  v.pre  (June 24 2008, August 26, 2010)
#	
#	cassidy -h for commands.
#
# By Adrian Fraiha
#

#Authors of a Blog:
# getent group <groupname>
# grep "^groupname" /etc/group

#Add author to a blog:
# useradd -G {group-name} {username}

#Remove user
# usermod -G {groupname} {username}

# Edit this if you do not have root access.
CAS_CONFIG=/etc/cassidy.conf


set -e
set -u

VERSION="\nCassidy v. Alpha \nhttp://dev.catch-colt.com/cassidy\nThis \
software is not copyrighted, do as you wish to it but if you use it, it'd be nice to link back to it!\n"
EDITOR=${EDITOR:-vim}
# FUNCTIONS

#ERR: Maybe set inputs to blog name where neccesary? $2 arguement
#	Input:	Blog name.
#	Output:	Path to blog name. $BLOG_PATH=/path/to/blog_name
get_blog_path() {
	BLOG_PATH=`awk -F: 'BEGIN{OFS="/"}
						/^'$1'/{print $2,$1}' $CAS_CONFIG`
}
#	Precondition: Blog path must be set. Run get_blog_path.
#	Input:	Null
#	Output:	Page extension. $PAGE_EXT=.ext 
get_page_extension() {
	PAGE_EXT=`awk '/page-ext/{print $2}' $BLOG_PATH/*.conf`
}
#	Precondition: Blog path must be set. Run get_blog_path.
#	Input:	Null
#	Output:	Number of posts in blog.
get_num_of_posts() {
	NUM_POSTS=`ls -1 $BLOG_PATH/posts | wc -l`
}
#ERR: No longer neccesary - gonna use groups and shit ya know?
#	Precondition: Blog path must be set. Run get_blog_path.
#	Input: Null
#	Output: Prevents a user from continuing, exit 0.
#authenticate_user() {
#	sed -ne '1,/^authors/d;/name/d;/email/d;s/ //g;s/://g;p' $BLOG_PATH/*.conf |awk '
#			/adrian/{print $0}
#		' | `read $0`
#	AUTHENTICATED=$(sed -ne '/authors/!d;s/authors: *//;p' $BLOG_PATH/*.conf |
#	awk -v user=`whoami` '
#	BEGIN{FS=",";X=0}
#	{ 
#		while ( $(X++) ) {
#			if("blog"==$X) { 
#				print 1;
#				exit;
#			}
#		}
#		print 0
#	}
#	')
#
# 	if [ $AUTHENTICATED -eq 0 ]; then
#		echo "You don't got the RIGHTS to funk with this blong."
#		exit 0
#	fi
#}

usage() {
	echo "
	Usage:	cassidy [COMMAND] [BLOG_NAME] [OPTIONS]
	
	Commands:
		create	<blog>
			Creates a new <blog> with name <blog>.
		
		post	<blog>	<url_title>
			Creates a new post to <blog>. <url_title>.ext
		
		list	<blog>
			Lists all posts in <blog>.
		
		edit	<blog>	<postID>
			Edits <postID> in <blog>.
		
		list
			Lists all blog names and paths.
		
		edit	<blog>
			Edits <blog>'s config file.

		regen	<blog>
			Regenerates every post. Use after editing <blog>.conf
			Use with cushion.

		authors <blog>

"
	exit 0
}

#In case $1 not set.
CMD=${1:-nocmd}
case "$CMD" in
	create)
	BLOG_NAME=$2

	echo "
	WELCOME TO CASSIDY!
	You are about to create a new bl... Doing so will
	create the following directory structure in the path
	you have yet to set:
		
	/$2
		$2.conf	<- Blumhg configuration file.
		
		htdocs/		<- Server points to here.
		
		templates/	<- Template files for your layout.
			
		posts/		<- RAW posts.

		Before I may continue, I need you to answer a couple 
		questions for me. These may be changed at a later time.
		"
#ERR: Check for empty.
		echo -n "User (login name) blog is for (default is `whoami`): "; read USERNAME
		echo ""
		USERNAME=${USERNAME:-`whoami`}	
		echo -n "Group blog is for (default is www): "; read GROUP
		echo""
		GROUP=${GROUP:-www}
		echo -n "Path to blog: (default is `pwd`/$BLOG_NAME): "; read BLOG_PATH
		echo ""
		BLOG_PATH=${BLOG_PATH:-`pwd`}
		grep -q "$BLOG_NAME:$BLOG_PATH" $CAS_CONFIG &&\
			{
				echo -e "Error: $BLOG_PATH/$BLOG_NAME already exits.\nSee cassidy -h on how to delete a bloag."
				exit 0
			}
		echo -n "Your Name: "; read NAME
		echo ""
		echo -n "Your Email: "; read EMAIL
		echo ""
		echo -n "Your Site Name: "; read SITE_NAME
		echo ""
		echo -n "Your Site URL (http://catch-colt.com): "; read SITE_URL
		echo ""
		echo -n "Extension (default is .htm): "; read PAGE_EXT
		echo ""
		PAGE_EXT=${PAGE_EXT:-.htm}
#	Set up cassidy config file.
		echo "$BLOG_NAME:$BLOG_PATH" | sudo tee -a $CAS_CONFIG >> /dev/null
#	Set up directory structure.
		sudo mkdir -p $BLOG_PATH/$BLOG_NAME
		sudo chown $USERNAME $BLOG_PATH/$BLOG_NAME 
		cd $BLOG_PATH/$BLOG_NAME
		mkdir -p htdocs/styles posts templates
		grep -q $GROUP /etc/group ||\
      {
        echo -e "Group $GROUP does not exist, creating..."
        sudo groupadd $GROUP
      }
    id $USERNAME | grep -q $GROUP ||\
      {
        echo -e "Adding $USERNAME to $GROUP..."     
        sudo  usermod -a -G $GROUP $USERNAME
      }
    sudo chown :$GROUP posts htdocs
		chmod 775 posts htdocs
		touch $BLOG_NAME.conf
	   {
			echo "# $BLOG_NAME.conf: A cassidy blog config file." 
			echo "site-name: $SITE_NAME"
			echo "site-url: $SITE_URL"
			echo "page-ext: $PAGE_EXT"
			echo "date-format: %m/%d/%y %H:%M:%S"
			echo "authors: "
			echo  "  $USERNAME:"
			echo  "    name: $NAME"
			echo  "    email: $EMAIL"
		} > $BLOG_NAME.conf

		$EDITOR $BLOG_NAME.conf
		echo "Your new blog has been created. Type cassidy -h for options on what to do"
	;;

	-p|--p|P|p|po|pos|post)
		if [ $# -ge 3 ]; then
			get_blog_path $2
			# Stops here if user is not an author
#			authenticate_user
	
			get_num_of_posts
			CURR_POST=`expr $NUM_POSTS + 1`
			{
				echo "title: Title"
				echo "created: `date -u --rfc-3339=seconds`"
				echo "updated: Never"
				echo "content: ..."
			} >> $BLOG_PATH/posts/$CURR_POST\_$3.yml
			$EDITOR $BLOG_PATH/posts/$CURR_POST\_$3.yml
	
#ERR: If person does not save post, erase the template file.
#			if [ $? -eq 1 ]; then
#				rm $BLOG_PATH/posts/$CURR_POST$3.yml
#				echo "Post aborted."
#				exit 1
#			fi
#	Should offer support not to regenerate.
			echo "Post created to publish generate ID $CURR_POST."
			exit 0
		fi
		usage
	;;

	-l|--l|L|l|li|lis|list)
		if [ $# -eq 1 ]; then
			echo -e "\n\t\tLIST OF BLOGS"
			echo -e "\tNAME:\t\t\tPATH:"
			awk -F: -v OFS="\t\t\t" \
					'{print "\t"$1,$2}' $CAS_CONFIG
			echo ""
			exit 0
		fi

#ERR: Can truncate Title. At which point, can show date posted or URL.
		if [ $# -eq 2 ]; then
			get_blog_path $2
			echo -e "\n\tID\t TITLE"
			#	FS requires a letter before due to date times.
			
		  ls $BLOG_PATH/posts/ | grep  'yml' &&\
      {
        awk '
				BEGIN {FS="[a-zA-Z]:"; ORS="";}
        /title/{print "\t"++i"\t"$2"\n"}
			  ' $BLOG_PATH/posts/*
      } ||\
      {
        echo "   Nothing has been written!"
      }
			echo ""
			exit 0
		fi
		usage
	;;
	-g|--g|G|g|ge|gen|gene|gener|genera|generat|generate)
		if [ $# -eq 3 ]; then
			get_blog_path $2
			get_page_extension
      POST_ID=$3
			# Do post first.
		 	tpl=`cat $BLOG_PATH/templates/header.tpl $BLOG_PATH/templates/entry.tpl $BLOG_PATH/templates/footer.tpl`
			# Set variables.
			# $SITE_NAME
			# $SITE_URL
			# $POST_PERM_LINK
			# $POST_CREATED
			# $POST_UPDATED
			# $POST_TITLE
			# $POST_AUTHOR
			# $POST_CONTENT

		  POST_YML=`ls $BLOG_PATH/posts/ | grep  ^$POST_ID\_` &&\
      {
        SITE_NAME=`awk 'BEGIN {FS=": ";}/site-name/{ print $2 }' $BLOG_PATH/$2.conf`
        SITE_URL=`awk 'BEGIN {FS=": ";}/site-url/{ print $2 }' $BLOG_PATH/$2.conf`
        DATE_FORMAT=`awk 'BEGIN {FS=": ";}/date-format/{ print $2 }' $BLOG_PATH/$2.conf`
        PAGE_EXT=`awk 'BEGIN {FS=": ";}/page-ext/{ print $2 }' $BLOG_PATH/$2.conf`
        
        POST_TITLE=` awk 'BEGIN {FS="^title: ";}/title/{ print $2 }' $BLOG_PATH/posts/$POST_YML`
        POST_CREATED=` awk 'BEGIN {FS="^posted: ";}/posted/{ print $2 }' $BLOG_PATH/posts/$POST_YML`
        POST_UPDATED=`awk 'BEGIN {FS="^updated: ";}/updated/{ print $2 }' $BLOG_PATH/posts/$POST_YML`
        POST_CONTENT=`awk 'BEGIN {FS="^content: ";}/content/{ f=1 }f' $BLOG_PATH/posts/$POST_YML`
        POST_CONTENT=`echo $POST_CONTENT | sed --posix "s/content: //"`

				#Prepare DATE!
				POST_CREATED=`date "+$DATE_FORMAT" --date="$POST_CREATED"`
				
				if [ "$POST_UPDATED" != "Never" ]; then
					POST_UPDATED=`date "+$DATE_FORMAT" --date="$POST_UPDATED"`
				fi
         
        POST_AUTHOR=`whoami`
        POST_FILE_NAME=`echo $POST_YML | sed "s/\.yml$/$PAGE_EXT/"`

#ERR: Can't use backslashes in files. lol 
        echo $tpl  |	sed --posix "
					/{SITE_NAME}/s\{SITE_NAME}\\${SITE_NAME}\g;
					/{SITE_URL}/s\{SITE_URL}\\${SITE_URL}\g;
					/{POST_CONTENT}/s\{POST_CONTENT}\\${POST_CONTENT}\g;
					/{POST_ID}/s\{POST_ID}\\${POST_ID}\g;
          /{POST_CREATED}/s\{POST_CREATED}\\${POST_CREATED}\g;
					/{POST_UPDATED}/s\{POST_UPDATED}\\${POST_UPDATED}\g;
					/{POST_TITLE}/s\{POST_TITLE}\\${POST_TITLE}\g;
					/{POST_AUTHOR}/s\{POST_AUTHOR}\\${POST_AUTHOR}\g;
					" > $BLOG_PATH/htdocs/$POST_FILE_NAME
      } || {
        echo 'There was an error in generating your post, it may have not been found or there may be a "\" in one of your files!'
        exit 0
      }
      echo "Post has been published, check it out: $SITE_URL/$POST_FILE_NAME !"
			exit 0
		fi
		usage
	;;
	-e|--e|E|e|ed|edi|edit)
    #Edit Blog
		if [ $# -eq 2 ]; then
			get_blog_path $2
      if [ -s $BLOG_PATH/$2.conf ]; then
  		  $EDITOR $BLOG_PATH/$2.conf	
  			exit 0
      fi
		fi

		if [ $# -eq 3 ]; then
			get_blog_path $2
		  	
		  YML_NAME=`ls $BLOG_PATH/posts/ | grep  ^$3\_` &&\
      {
        echo $YML_NAME
        NOW=`date -u --rfc-3339=seconds`
#       cat $BLOG_PATH/posts/$YML_NAME | sed -e "s/^updated: .*/updated: $NOW/" > $BLOG_PATH/posts/$YML_NAME
        sed -i "s/^updated: .*/updated: $NOW/" $BLOG_PATH/posts/$YML_NAME
 
        vim $BLOG_PATH/posts/$YML_NAME
			  echo "Post updated to publish generate ID $3." 
        exit 0
      } || {
        echo "Post #$3 does not exist in "$2". See cassidy -h."  
      }
      exit 0
		fi
		usage
  ;;
	-v|--v|V|v|ve|ver|vers|versi|versio|version)
		echo -e $VERSION
		exit 0
	;;
	-h|--h|H|h|he|hel|help|*)
		usage
	;;
esac

