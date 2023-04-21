# frozen_string_literal: true

RSpec.describe SidebarSectionsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    ### TODO remove when enable_custom_sidebar_sections SiteSetting is removed
    group = Fabricate(:group)
    Fabricate(:group_user, group: group, user: user)
    Fabricate(:group_user, group: group, user: admin)
    SiteSetting.enable_custom_sidebar_sections = group.id.to_s
  end

  describe "#index" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, title: "private section", user: user) }
    fab!(:sidebar_url_1) { Fabricate(:sidebar_url, name: "tags", value: "/tags") }
    fab!(:section_link_1) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end
    fab!(:sidebar_section_2) do
      Fabricate(:sidebar_section, title: "public section", user: admin, public: true)
    end
    fab!(:section_link_2) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end

    it "returns public and private sections" do
      sign_in(user)
      get "/sidebar_sections.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["sidebar_sections"].map { |section| section["title"] }).to eq(
        ["public section", "private section"],
      )
    end
  end

  describe "#create" do
    it "is not available for anonymous" do
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "link", name: "tags", value: "/tags" },
             ],
           }
      expect(response.status).to eq(403)
    end

    it "creates custom section for user" do
      sign_in(user)
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "address-book", name: "tags", value: "/tags" },
             ],
           }

      expect(response.status).to eq(200)

      expect(SidebarSection.count).to eq(1)
      sidebar_section = SidebarSection.last

      expect(sidebar_section.title).to eq("custom section")
      expect(sidebar_section.user).to eq(user)
      expect(sidebar_section.public).to be false
      expect(UserHistory.count).to eq(0)
      expect(sidebar_section.sidebar_urls.count).to eq(2)
      expect(sidebar_section.sidebar_urls.first.icon).to eq("link")
      expect(sidebar_section.sidebar_urls.first.name).to eq("categories")
      expect(sidebar_section.sidebar_urls.first.value).to eq("/categories")
      expect(sidebar_section.sidebar_urls.second.icon).to eq("address-book")
      expect(sidebar_section.sidebar_urls.second.name).to eq("tags")
      expect(sidebar_section.sidebar_urls.second.value).to eq("/tags")
    end

    it "does not allow regular user to create public section" do
      sign_in(user)
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "address-book", name: "tags", value: "/tags" },
             ],
           }
      expect(response.status).to eq(403)
    end

    it "allows admin to create public section" do
      sign_in(admin)
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "address-book", name: "tags", value: "/tags" },
             ],
           }
      expect(response.status).to eq(200)

      sidebar_section = SidebarSection.last
      expect(sidebar_section.title).to eq("custom section")
      expect(sidebar_section.public).to be true

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:create_public_sidebar_section])
      expect(user_history.subject).to eq("custom section")
      expect(user_history.details).to eq("links: categories - /categories, tags - /tags")
    end
  end

  describe "#update" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }
    fab!(:sidebar_url_1) { Fabricate(:sidebar_url, name: "tags", value: "/tags") }
    fab!(:sidebar_url_2) { Fabricate(:sidebar_url, name: "categories", value: "/categories") }
    fab!(:section_link_1) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end
    fab!(:section_link_2) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)
    end

    it "allows user to update their own section and links" do
      sign_in(user)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
            ],
          }

      expect(response.status).to eq(200)

      expect(sidebar_section.reload.title).to eq("custom section edited")
      expect(UserHistory.count).to eq(0)
      expect(sidebar_url_1.reload.name).to eq("latest")
      expect(sidebar_url_1.value).to eq("/latest")
      expect { section_link_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sidebar_url_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "allows admin to update public section and links" do
      sign_in(admin)
      sidebar_section.update!(user: admin, public: true)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
            ],
          }

      expect(response.status).to eq(200)

      expect(sidebar_section.reload.title).to eq("custom section edited")
      expect(sidebar_url_1.reload.name).to eq("latest")
      expect(sidebar_url_1.value).to eq("/latest")
      expect { section_link_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sidebar_url_2.reload }.to raise_error(ActiveRecord::RecordNotFound)

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:update_public_sidebar_section])
      expect(user_history.subject).to eq("custom section edited")
      expect(user_history.details).to eq("links: latest - /latest")
    end

    it "doesn't allow to edit other's sections" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      sidebar_url_3 = Fabricate(:sidebar_url, name: "other_tags", value: "/tags")
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section_2, linkable: sidebar_url_3)
      sign_in(user)
      put "/sidebar_sections/#{sidebar_section_2.id}.json",
          params: {
            title: "custom section edited",
            links: [{ icon: "link", id: sidebar_url_3.id, name: "takeover", value: "/categories" }],
          }

      expect(response.status).to eq(403)
    end

    it "doesn't allow to edit public sections" do
      sign_in(user)
      sidebar_section.update!(public: true)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
            ],
          }
      expect(response.status).to eq(403)
    end

    it "doesn't allow to edit other's links" do
      sidebar_url_3 = Fabricate(:sidebar_url, name: "other_tags", value: "/tags")
      Fabricate(
        :sidebar_section_link,
        sidebar_section: Fabricate(:sidebar_section),
        linkable: sidebar_url_3,
      )
      sign_in(user)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [{ icon: "link", id: sidebar_url_3.id, name: "takeover", value: "/categories" }],
          }

      expect(response.status).to eq(404)

      expect(sidebar_url_3.reload.name).to eq("other_tags")
    end
  end

  describe "#destroy" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }

    it "allows user to delete their own section" do
      sign_in(user)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(200)

      expect { sidebar_section.reload }.to raise_error(ActiveRecord::RecordNotFound)

      expect(UserHistory.count).to eq(0)
    end

    it "allows admin to delete public section" do
      sign_in(admin)
      sidebar_section.update!(user: admin, public: true)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(200)

      expect { sidebar_section.reload }.to raise_error(ActiveRecord::RecordNotFound)

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:destroy_public_sidebar_section])
      expect(user_history.subject).to eq("Sidebar section")
    end

    it "doesn't allow to delete other's sidebar section" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      sign_in(user)
      delete "/sidebar_sections/#{sidebar_section_2.id}.json"

      expect(response.status).to eq(403)
    end

    it "doesn't allow to delete public sidebar section" do
      sign_in(user)
      sidebar_section.update!(public: true)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(403)
    end
  end
end
