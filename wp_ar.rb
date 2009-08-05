require 'activerecord'

# Adapted from http://snippets.dzone.com/posts/show/1314 and
# considerably extended

class ActiveRecord::Wordpress < ActiveRecord::Base
  self.abstract_class = true
  establish_connection(
    :adapter => "mysql",
    :host => "localhost",
    :username => "",
    :database => ""
  )
end

class WpBlogComment < ActiveRecord::Wordpress

  # if wordpress tables live in a different database (i.e. 'wordpress') change the following
  # line to set_table_name "wordpress.wp_comments"
  # don't forget to give the db user permissions to access the wordpress db
  set_table_name "wp_comments"
  set_primary_key "comment_ID"

  belongs_to :post , :class_name => "WpBlogPost", :foreign_key => "comment_post_ID"

  validates_presence_of :comment_post_ID, :comment_author, :comment_content, :comment_author_email

  def validate_on_create
    if WpBlogPost.find(comment_post_ID).comment_status != 'open'
      errors.add_to_base('Sorry, comments are closed for this post')
    end
  end

end

class WpPostMeta < ActiveRecord::Wordpress
  set_table_name "wp_postmeta"
  set_primary_key "meta_id"
  belongs_to :blog_post, :foreign_key => :post_id, :class_name => 'WpBlogPost'
end

class WpBlogPost < ActiveRecord::Wordpress

  set_table_name "wp_posts"
  set_primary_key "ID"

  has_many :comments, :class_name => "WpBlogComment", :foreign_key => "comment_post_ID"
  has_many :metas, :class_name => 'WpPostMeta', :foreign_key => 'post_id'

  has_many :term_relationships, :class_name => 'WpTermRelationship', :foreign_key => 'object_id'
  has_many :term_taxonomies, :through => :term_relationships
  has_many :taggings, :through => :term_relationships, :source => :term_taxonomy, :conditions => ['wp_term_taxonomy.taxonomy = ?', 'post_tag']

  named_scope :published, :conditions => {:post_status => 'publish'}
  default_scope :order => 'post_date DESC'

  def published?
    self.status == 'published' and self.post_date <= DateTime.now
  end
  
  def tags
    taggings.collect(&:term)
  end
 
  def self.find_by_permalink(year, month, day, title)
    first(:conditions => ["YEAR(post_date) = ? AND MONTH(post_date) = ? AND DAYOFMONTH(post_date) = ? AND post_name = ?",
      year.to_i, month.to_i, day.to_i, title])
  end
end

class WpTerm < ActiveRecord::Wordpress
  set_table_name 'wp_terms'
  set_primary_key 'term_id'
  has_many :taxonomies, :class_name => 'WpTermTaxonomy', :foreign_key => 'term_id'
  has_many :relationships, :through => :taxonomies
 
  def posts
    relationships.collect(&:post)
  end
end

class WpTermTaxonomy < ActiveRecord::Wordpress
  set_table_name "wp_term_taxonomy"
  set_primary_key 'term_taxonomy_id'
  belongs_to :term, :class_name => 'WpTerm'
  has_many :relationships, :class_name => 'WpTermRelationship', :foreign_key => 'term_taxonomy_id'
end

class WpTermRelationship < ActiveRecord::Wordpress
  set_table_name "wp_term_relationships"
  belongs_to :post, :class_name => 'WpBlogPost', :foreign_key => 'object_id'
  belongs_to :term_taxonomy, :class_name => 'WpTermTaxonomy'
end

class WpLink < ActiveRecord::Wordpress
  set_primary_key 'link_id'
end

class WpUser < ActiveRecord::Wordpress
  set_primary_key 'ID'
  has_many :meta_details, :class_name => 'WpUserMeta', :foreign_key => 'user_id'
  before_validation_on_create :store_registration_time
  
  validates_presence_of :user_registered
  
  def store_registration_time
    self.user_registered ||= DateTime.now
  end
  
  class <<self
    # Note: Recent versions of WP do not simply store an MD5
    # they use PHPPass (wp-includes/class-phpass.php)
    # If anyone has written a ruby equivalent, please let me know so I 
    # can integrate it
    def encrypt(password)
      Digest::MD5.hexdigest(password)
    end
  end
end

class WpUserMeta < ActiveRecord::Wordpress
  set_primary_key 'umeta_id'
  belongs_to :user, :class_name => 'WpUser'
end

class WpOption < ActiveRecord::Wordpress
  set_primary_key 'option_id'
end
