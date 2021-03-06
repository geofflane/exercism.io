class Team < ActiveRecord::Base

  belongs_to :creator, class_name: "User"
  has_many :memberships, ->{ where confirmed: true }, class_name: "TeamMembership"
  has_many :unconfirmed_memberships, ->{ where confirmed: false }, class_name: "TeamMembership"
  has_many :members, through: :memberships, source: :user
  has_many :unconfirmed_members, through: :unconfirmed_memberships, source: :user
  has_many :management_contracts, class_name: "TeamManager"
  has_many :managers, through: :management_contracts, source: :user

  validates :creator, presence: true
  validates :slug, presence: true,  uniqueness: true

  before_validation :provide_default_name, :provide_default_slug, :normalize_slug

  def self.by(user)
    team = new(creator: user)
    team.managers << user
    team
  end

  def self.find_by_slug(slug)
    where('LOWER(slug) = ?', slug.downcase).first
  end

  def managed_by?(user)
    managers.include?(user)
  end

  def managed_by(user)
    managers << user unless managed_by?(user)
  end

  def defined_with(options)
    self.slug = options[:slug]
    self.name = options[:name]
    self.unconfirmed_members = User.find_in_usernames(options[:usernames].to_s.scan(/\w+/)) if options[:usernames]
    self
  end

  def recruit(usernames)
    self.unconfirmed_members += User.find_in_usernames(usernames.to_s.scan(/[\w-]+/))
  end

  def dismiss(username)
    user = User.where(username: username.to_s).first
    self.members.delete(user)
    self.unconfirmed_members.delete(user)
  end

  def confirm(username)
    user = User.where(username: username.to_s).first
    self.unconfirmed_memberships.where(user_id: user.id).first.confirm!
    self.unconfirmed_members.reload
    self.members.reload
  end

  def usernames
    members.map(&:username)
  end

  def includes?(user)
    creator == user || members.include?(user)
  end

  def all_members
    members + unconfirmed_members
  end

  private

  def normalize_slug
    return unless slug
    self.slug = slug.gsub('_', '-').parameterize('-')
  end

  def provide_default_slug
    self.slug ||= self.name
  end

  def provide_default_name
    self.name = self.slug if name.blank?
  end
end
