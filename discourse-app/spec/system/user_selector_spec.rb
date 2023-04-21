# frozen_string_literal: true

describe "User selector", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:current_user) { Fabricate(:admin) }

  before do
    current_user.activate
    sign_in(current_user)
  end

  context "when autocompleting a username" do
    it "correctly shows the user" do
      visit("/t/-/#{topic.id}")
      find(".btn-primary.create").click
      find(".d-editor-input").fill_in(with: "Hello @dis")

      within(".autocomplete.ac-user") do |el|
        expect(el).to have_selector(".selected .avatar[title=discobot]")
        expect(el.find(".selected .username")).to have_content("discobot")
      end
    end
  end

  context "when autocompleting a group" do
    it "correctly shows the user" do
      visit("/t/-/#{topic.id}")
      find(".btn-primary.create").click
      find(".d-editor-input").fill_in(with: "Hello @adm")

      within(".autocomplete.ac-user") do |el|
        expect(el).to have_selector(".selected .d-icon-users")
        expect(el.find(".selected .username")).to have_content("admins")
      end
    end
  end
end
