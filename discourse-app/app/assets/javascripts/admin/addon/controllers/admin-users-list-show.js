import discourseComputed, { observes } from "discourse-common/utils/decorators";
import AdminUser from "admin/models/admin-user";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import Controller from "@ember/controller";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { i18n } from "discourse/lib/computed";

export default Controller.extend(CanCheckEmails, {
  model: null,
  query: null,
  order: null,
  asc: null,
  showEmails: false,
  refreshing: false,
  listFilter: null,
  selectAll: false,
  searchHint: i18n("search_hint"),

  init() {
    this._super(...arguments);

    this._page = 1;
    this._results = [];
    this._canLoadMore = true;
  },

  @discourseComputed("query")
  title(query) {
    return I18n.t("admin.users.titles." + query);
  },

  @discourseComputed("showEmails")
  columnCount(showEmails) {
    let colCount = 7; // note that the first column is hardcoded in the template

    if (showEmails) {
      colCount += 1;
    }

    if (this.siteSettings.must_approve_users) {
      colCount += 1;
    }

    return colCount;
  },

  @observes("listFilter")
  _filterUsers() {
    discourseDebounce(this, this.resetFilters, INPUT_DELAY);
  },

  resetFilters() {
    this._page = 1;
    this._results = [];
    this._canLoadMore = true;
    this._refreshUsers();
  },

  _refreshUsers() {
    if (!this._canLoadMore) {
      return;
    }

    const page = this._page;
    this.set("refreshing", true);

    AdminUser.findAll(this.query, {
      filter: this.listFilter,
      show_emails: this.showEmails,
      order: this.order,
      asc: this.asc,
      page,
    })
      .then((result) => {
        this._results[page] = result;
        this.set("model", this._results.flat());

        if (result.length === 0) {
          this._canLoadMore = false;
        }
      })
      .finally(() => {
        this.set("refreshing", false);
      });
  },

  actions: {
    loadMore() {
      this._page += 1;
      this._refreshUsers();
    },

    toggleEmailVisibility() {
      this.toggleProperty("showEmails");
      this.resetFilters();
    },
  },
});
