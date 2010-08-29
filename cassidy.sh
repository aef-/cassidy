#!/bin/sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	
#  Cassidy v.pre (August 28,2010) 
#   - A Shell-based blogging system.
#  By aef 
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

CAS_CONFIG=/etc/cassidy.conf
EDITOR=${EDITOR:-vim}


set -e
set -u


VERSION="\nCassidy v.pre \nhttp://dev.catch-colt.com/cassidy\nThis \
software is not copyrighted, do as you wish to it but if you use it, it'd be nice to link back to it!\n"



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
# Precondition: Blog path must be set. Run get_blog_path.
# Input: Null
# Output: The last post ID and the last post ID + 1.
get_curr_post_id() {
  LAST_POST_ID=`ls $BLOG_PATH/posts | sort -n  | tail -1  | sed -e "s/\(^[0-9]*\)_.*$/\1/"`
  CURR_POST_ID=$[$LAST_POST_ID + 1]
}

usage() {
	echo "
	Usage:	cassidy [COMMAND] [BLOG_NAME] [OPTIONS]
	
	Commands:
		create	<blog>
			Creates a new <blog> with name <blog>. (Keep it simple)
		
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

		gen	<blog> <postID>
			Generate HTML of post.
		
		gen	<blog> 
			Generates every post in <blog>.
"
	exit 0
}

# Precondition: Blog path must be set. Run get_blog_path.
# Input: Blog name.
# Output: Generates index.ext HTML.
generate_index_html() {
      INDEX_TPL=`cat $BLOG_PATH/templates/index.tpl`
      LAYOUT_TPL=`cat $BLOG_PATH/templates/layout.tpl`
      INDEX_TPL=`echo $INDEX_TPL`
                                            # Paper boy jumps are annoying!
      INDEX_TPL=`echo $LAYOUT_TPL | sed --posix "s\{CONTENT}\\\\${INDEX_TPL}\g;"`
       
      SITE_NAME=`awk 'BEGIN {FS=": ";}/site-name/{ print $2 }' $BLOG_PATH/$1.conf`
      SITE_URL=`awk 'BEGIN {FS=": ";}/site-url/{ print $2 }' $BLOG_PATH/$1.conf`
      PAGE_EXT=`awk 'BEGIN {FS=": ";}/page-ext/{ print $2 }' $BLOG_PATH/$1.conf`

      #List of published titles to post, sorted by ID.
#ERR: Not sure about this.. Any insight from gurus?
      LIST_POSTS=$({
        for i in `ls $BLOG_PATH/posts | grep ^[0-9]*_ | sort -n | tac`
          do
          URL=`echo $i | sed "s/\.yml/${PAGE_EXT}/"` 
          echo `awk 'BEGIN {FS="^title: ";}/title/{ print "<li><a href=\"/posts/'$URL'\">"$2"</a></li>" }' $BLOG_PATH/posts/$i` 
        done
      })
      LIST_POSTS=`echo $LIST_POSTS`
        echo -e $INDEX_TPL"\n" |	sed --posix "
					/{SITE_NAME}/s\{SITE_NAME}\\~${SITE_NAME}\g;
					/{SITE_URL}/s\{SITE_URL}\\${SITE_URL}\g;
					/{LIST_POSTS}/s\{LIST_POSTS}\\${LIST_POSTS}\g;
					" > $BLOG_PATH/htdocs/index.htm
      echo "Generated new index.htm." 
}

#	Precondition: Blog path must be set. Run get_blog_path.
#	Input:	Post #ID, blog name
#	Output: Generates HTML of post from post yaml.	
generate_post_html() {

      POST_ID=$1	

#ERR: Maybe put this in a function. haHa! we shall seE!
#ERR: There's gotta be a better way to prep for sed than to echo the contents. 
      POST_TPL=`cat $BLOG_PATH/templates/post.tpl`
      POST_TPL=`echo $POST_TPL`
      LAYOUT_TPL=`cat $BLOG_PATH/templates/layout.tpl`
      
      POST_TPL=`echo $LAYOUT_TPL | sed --posix "s\{CONTENT}\\\\${POST_TPL}\g;"`

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
        
        POST_TITLE=`awk 'BEGIN {FS="^title: ";}/title/{ print $2 }' $BLOG_PATH/posts/$POST_YML`
        POST_CREATED=`awk 'BEGIN {FS="^posted: ";}/posted/{ print $2 }' $BLOG_PATH/posts/$POST_YML`
        POST_UPDATED=`awk 'BEGIN {FS="^updated: ";}/updated/{ print $2 }' $BLOG_PATH/posts/$POST_YML`
        POST_CONTENT=`awk 'BEGIN {FS="^content: ";}/content/{ f=1 }f' $BLOG_PATH/posts/$POST_YML`
        POST_CONTENT=`echo $POST_CONTENT | sed --posix "s/content: //"`

				#Prepare DATE!
				POST_CREATED=`date "+$DATE_FORMAT" --date="$POST_CREATED"`
#for V1: 
# POST_UPDATED=`stat -c %y $BLOG_PATH/posts/$POST_YML`
				if [ "$POST_UPDATED" != "Never" ]; then
					POST_UPDATED=`date "+$DATE_FORMAT" --date="$POST_UPDATED"`
				fi
         
        POST_AUTHOR=`stat -c %U $BLOG_PATH/posts/$POST_YML`
        POST_FILE_NAME=`echo $POST_YML | sed "s/\.yml$/$PAGE_EXT/"`

#ERR: Can't use backslashes in files. hmm..
#ERR: Not exactly necessary to have line search since all the templates have been fudged into one line.
        echo $POST_TPL  |	sed --posix -e "
					/{SITE_NAME}/s\{SITE_NAME}\\${SITE_NAME}\g;
					/{SITE_URL}/s\{SITE_URL}\\${SITE_URL}\g;
					/{POST_CONTENT}/s\{POST_CONTENT}\\${POST_CONTENT}\g;
					/{POST_ID}/s\{POST_ID}\\${POST_ID}\g;
          /{POST_CREATED}/s\{POST_CREATED}\\${POST_CREATED}\g;
					/{POST_UPDATED}/s\{POST_UPDATED}\\${POST_UPDATED}\g;
					/{POST_TITLE}/s\{POST_TITLE}\\${POST_TITLE}\g;
					/{POST_AUTHOR}/s\{POST_AUTHOR}\\${POST_AUTHOR}\g;
					" > $BLOG_PATH/htdocs/posts/$POST_FILE_NAME
        chown $POST_AUTHOR $BLOG_PATH/htdocs/posts/$POST_FILE_NAME
        echo $SITE_URL/$POST_FILE_NAME
      } || {
        echo 1
      } 
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
		echo -n "Group blog is for (default is $BLOG_NAME): "; read GROUP
		echo""
		GROUP=${GROUP:-$BLOG_NAME}
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
		mkdir -p htdocs/styles htdocs/posts posts templates
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
    #Template:
		touch templates/layout.tpl
      {
        echo '<html>'
        echo '  <head>'
        echo '    <title>{SITE_NAME}</title>'
        echo '  </head>'
        echo '  <body>'
        echo '    {CONTENT}'
        echo '  </body>'
        echo '</html>'
      } > templates/layout.tpl

    touch templates/post.tpl
      {
        echo '<h1>{POST_TITLE}</h1>'
        echo '{POST_CONTENT}'
        echo 'Posted by {POST_AUTHOR} on {POST_CREATED}'
      } > templates/post.tpl

    touch templates/index.tpl
      {
        echo '<ul>'
        echo '{LIST_POSTS}'
        echo '</ul>'
      } > templates/index.tpl

    touch $BLOG_NAME.conf
	   {
			echo "# $BLOG_NAME.conf: A cassidy blog config file." 
			echo "site-name: $SITE_NAME"
			echo "site-url: $SITE_URL"
			echo "page-ext: $PAGE_EXT"
			echo "date-format: %m/%d/%y %H:%M:%S"
			echo "authors: "
			echo "  $USERNAME:"
			echo "    name: $NAME"
			echo "    email: $EMAIL"
		} > $BLOG_NAME.conf

		$EDITOR $BLOG_NAME.conf
		echo "Your new blog has been created. Type cassidy -h for options on what to do."
	;;

	-p|--p|P|p|po|pos|post)
		if [ $# -ge 3 ]; then
			get_blog_path $2
      get_curr_post_id
			CURR_POST=$CURR_POST_ID
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
			  ' $BLOG_PATH/posts/*.yml
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
      POST_URL=`generate_post_html $3 $2`
      if [ $POST_URL == 1 ]; then
        echo "Post #$3 of $2 could not be generated."
      else
        echo "Post has been published, check it out: $POST_URL !"
      fi
      generate_index_html $2
			exit 0
		fi
    if [ $# -eq 2 ]; then
      get_blog_path $2
      get_page_extension

      get_num_of_posts

      echo 'Generating blog posts, will display only errors.'
      for i in `ls $BLOG_PATH/posts | sort -n  | sed -e "s/\(^[0-9]*\)_.*$\1/"`
          do
          ERR=`generate_post_html $i $2`
          if [ $ERR == 1 ]; then
            echo "Post #$i of $2 could not be generated."
          fi
      done
      generate_index_html $2
      echo 'Finished.'
      exit 0
    fi
		usage
	;;
  -d|--d|D|d|de|del|dele|delet|delete)
    #Delete blog
		if [ $# -eq 2 ]; then
      echo "Not yet implemented. To remove delete folder and remove record from $CAS_CONFIG"
    fi
    #Delete post    
		if [ $# -eq 3 ]; then
      echo "Not yet implemented. To delete a post remove it from /posts and /htdocs" 
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

    #Edit Post
		if [ $# -eq 3 ]; then
			get_blog_path $2
		  	
		  YML_NAME=`ls $BLOG_PATH/posts/ | grep  ^$3\_` &&\
      {
        NOW=`date -u --rfc-3339=seconds`
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
  -t) # Test Command, used for debugging. Should always be empty, except for when it's not.
    set -x
    get_blog_path $2
    echo `generate_post_html 1 $2`
  ;;
	-v|--v|V|v|ve|ver|vers|versi|versio|version)
		echo -e $VERSION
		exit 0
	;;
	-h|--h|H|h|he|hel|help|*)
		usage
	;;
esac

