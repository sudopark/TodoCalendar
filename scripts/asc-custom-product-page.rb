#!/usr/bin/env ruby
# frozen_string_literal: true

# App Store Connect 맞춤형 제품 페이지(Custom Product Page)를 만들고 채운다.
#
# usage (PATH 는 docs/appstore-connect-operations.md §1, 자격증명은 secret/README.md):
#   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
#   bundle exec ruby scripts/asc-custom-product-page.rb list
#   bundle exec ruby scripts/asc-custom-product-page.rb create
#   bundle exec ruby scripts/asc-custom-product-page.rb push-text   (--page <id>|--all-pages) (--locale <ASC로케일>|--all-locales) [--dry-run]
#   bundle exec ruby scripts/asc-custom-product-page.rb push-images (--page <id>|--all-pages) (--locale <ASC로케일>|--all-locales) [--dry-run]
#
# fastlane deliver 는 맞춤형 제품 페이지를 모른다. 그래서 lane 이 아니라 spaceship 의
# raw ASC 클라이언트를 직접 쓴다 (asc-in-app-event.rb 와 같은 구조).
#
# **인앱 이벤트와 커밋 페이로드가 다르다** — 여기는 appScreenshots 라 sourceFileChecksum 을
# 반드시 싣는다. appEventScreenshots 에 실으면 거부되는 그 필드다.

require "digest"
require "json"
require "spaceship"

REQUIRED_ENV = {
  "ASC_KEY_ID" => "App Store Connect > 사용자 및 액세스 > 통합에서 발급한 키 ID",
  "ASC_ISSUER_ID" => "같은 화면의 Issuer ID",
  "ASC_KEY_CONTENT" => "AuthKey_<키ID>.p8 를 base64 로 인코딩한 값 — base64 -i AuthKey_<키ID>.p8"
}.freeze

SECRET_KEYS = %w[key_id issuer_id key_filepath].freeze

ROOT = File.expand_path("..", __dir__)
CONFIG_ROOT = ENV["CPP_CONFIG_ROOT"] || File.join(ROOT, "fastlane", "custom_product_pages")
METADATA_ROOT = File.join(ROOT, "fastlane", "metadata")

PROMOTIONAL_TEXT_FILE = "promotional_text.txt"
PROMOTIONAL_TEXT_LIMIT = 170
SCREENSHOT_DISPLAY_TYPE = "APP_IPHONE_67"
SCENES_PER_PAGE = 6

# deliver 가 로케일이 아닌 용도로 쓰는 하위 디렉토리 (fastlane/Fastfile 과 같은 목록)
NON_LOCALE_METADATA_DIRS = %w[
  review_information
  trade_representative_contact_information
  app_clip_review_information
].freeze

def abort_with(message)
  warn(message)
  exit(1)
end

# 자격증명 파일 경로. 테스트가 실제 자격증명을 안 집게 덮어쓸 수 있어야 한다.
def secret_path
  ENV["ASC_SECRET_FILE"] || File.join(ROOT, "secret", "asc-api-key.json")
end

def credentials_from_env
  missing = REQUIRED_ENV.select { |name, _| ENV[name].to_s.strip.empty? }
  return nil unless missing.empty?

  {
    key_id: ENV.fetch("ASC_KEY_ID"),
    issuer_id: ENV.fetch("ASC_ISSUER_ID"),
    key: ENV.fetch("ASC_KEY_CONTENT"),
    is_key_content_base64: true
  }
end

# .p8 은 base64 로 바꾸지 않는다 — Token.create 가 filepath 를 직접 읽는다.
def credentials_from_secret_file
  path = secret_path
  return nil unless File.exist?(path)

  parsed = begin
    JSON.parse(File.read(path))
  rescue JSON::ParserError => error
    abort_with("#{path} 가 JSON 이 아니다 — #{error.message}\n\n형식은 secret/README.md")
  end

  absent = SECRET_KEYS.reject { |key| parsed[key].to_s.strip.empty? == false }
  abort_with("#{path} 에 #{absent.join(", ")} 가 없다 — 형식은 secret/README.md") unless absent.empty?

  key_filepath = File.expand_path(parsed["key_filepath"])
  unless File.exist?(key_filepath)
    abort_with("key_filepath 가 가리키는 #{key_filepath} 가 없다 — .p8 을 옮겼거나 경로가 틀렸다")
  end

  { key_id: parsed["key_id"], issuer_id: parsed["issuer_id"], filepath: key_filepath }
end

def credentials
  resolved = credentials_from_env || credentials_from_secret_file
  return resolved if resolved

  abort_with(<<~MESSAGE)
    App Store Connect 자격증명을 못 찾았다. 둘 중 하나를 갖춰라.

    (1) #{secret_path} — 형식은 secret/README.md
        { "key_id": "...", "issuer_id": "...", "key_filepath": "/절대/경로/AuthKey_<키ID>.p8" }

    (2) 환경변수 셋 (CI 처럼 파일을 못 두는 자리)
    #{REQUIRED_ENV.map { |name, hint| "    #{name} — #{hint}" }.join("\n")}
  MESSAGE
end

def bundle_identifier
  appfile = File.join(ROOT, "fastlane", "Appfile")
  match = File.read(appfile)[/app_identifier\(["']([^"']+)["']\)/, 1]
  return match if match

  abort_with("fastlane/Appfile 에서 app_identifier 를 못 읽었다")
end

def authenticated_client
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**credentials)
  Spaceship::ConnectAPI.tunes_request_client
end

class ASCCustomProductPageClient
  def initialize(client:)
    @client = client
  end

  def app_id(bundle_id:)
    apps = @client.get(v1("apps"), { "filter[bundleId]" => bundle_id }).body["data"] || []
    apps.first&.dig("id")
  end

  def pages(app_id:)
    paged(v1("apps/#{app_id}/appCustomProductPages"), { "limit" => 200 })
  end

  # 페이지 하나만 만들 수는 없다 — 버전과 기본 로케일까지 한 요청에 실어야 통과한다.
  # 함께 만드는 리소스는 included 에 두고 `${lid}` 로 서로를 가리킨다.
  # visible 은 CREATE 에 못 싣는다 (ASC 가 요청 전체를 거부한다).
  def create_page(app_id:, name:, primary_locale:)
    version_lid = "${cpp-version}"
    localization_lid = "${cpp-localization}"
    body = {
      data: {
        type: "appCustomProductPages",
        attributes: { name: name },
        relationships: {
          app: { data: { type: "apps", id: app_id } },
          appCustomProductPageVersions: {
            data: [{ type: "appCustomProductPageVersions", id: version_lid }]
          }
        }
      },
      included: [
        {
          type: "appCustomProductPageVersions",
          id: version_lid,
          relationships: {
            appCustomProductPageLocalizations: {
              data: [{ type: "appCustomProductPageLocalizations", id: localization_lid }]
            }
          }
        },
        {
          type: "appCustomProductPageLocalizations",
          id: localization_lid,
          attributes: { locale: primary_locale }
        }
      ]
    }
    @client.post(v1("appCustomProductPages"), body).body["data"]
  end

  def primary_locale(app_id:)
    @client.get(v1("apps/#{app_id}")).body.dig("data", "attributes", "primaryLocale")
  end

  # 페이지를 만들면 버전이 딸려 오는 것이 보통이지만 보장은 없다 — 없으면 만든다.
  def version(page_id:)
    existing = paged(
      v1("appCustomProductPages/#{page_id}/appCustomProductPageVersions"), { "limit" => 50 }
    )
    return existing.first unless existing.empty?

    body = {
      data: {
        type: "appCustomProductPageVersions",
        relationships: {
          appCustomProductPage: { data: { type: "appCustomProductPages", id: page_id } }
        }
      }
    }
    @client.post(v1("appCustomProductPageVersions"), body).body["data"]
  end

  def localizations(version_id:)
    paged(
      v1("appCustomProductPageVersions/#{version_id}/appCustomProductPageLocalizations"),
      { "limit" => 200 }
    ).each_with_object({}) do |entry, collected|
      locale = entry.dig("attributes", "locale")
      collected[locale] = entry if locale
    end
  end

  def create_localization(version_id:, locale:, promotional_text:)
    body = {
      data: {
        type: "appCustomProductPageLocalizations",
        attributes: { locale: locale, promotionalText: promotional_text },
        relationships: {
          appCustomProductPageVersion: {
            data: { type: "appCustomProductPageVersions", id: version_id }
          }
        }
      }
    }
    @client.post(v1("appCustomProductPageLocalizations"), body).body["data"]
  end

  # PATCH 에는 locale 을 싣지 않는다 — 생성 시점에만 정해지는 값이다.
  def update_localization(id:, promotional_text:)
    body = {
      data: {
        type: "appCustomProductPageLocalizations",
        id: id,
        attributes: { promotionalText: promotional_text }
      }
    }
    @client.patch(v1("appCustomProductPageLocalizations/#{id}"), body).body["data"]
  end

  def screenshot_set(localization_id:)
    existing = paged(
      v1("appCustomProductPageLocalizations/#{localization_id}/appScreenshotSets"),
      { "limit" => 50 }
    ).find { |entry| entry.dig("attributes", "screenshotDisplayType") == SCREENSHOT_DISPLAY_TYPE }
    return existing if existing

    body = {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: SCREENSHOT_DISPLAY_TYPE },
        relationships: {
          appCustomProductPageLocalization: {
            data: { type: "appCustomProductPageLocalizations", id: localization_id }
          }
        }
      }
    }
    @client.post(v1("appScreenshotSets"), body).body["data"]
  end

  def screenshots(set_id:)
    paged(v1("appScreenshotSets/#{set_id}/appScreenshots"), { "limit" => 50 })
  end

  def delete_screenshot(id:)
    @client.delete(v1("appScreenshots/#{id}"))
  end

  # 예약(POST) → 바이너리 PUT → uploaded + 체크섬 PATCH commit 3단계.
  def upload_screenshot(set_id:, path:)
    bytes = File.binread(path)
    reserved = @client.post(v1("appScreenshots"), {
      data: {
        type: "appScreenshots",
        attributes: { fileSize: bytes.bytesize, fileName: File.basename(path) },
        relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set_id } } }
      }
    }).body["data"]

    Spaceship::ConnectAPI::FileUploader.upload(reserved.dig("attributes", "uploadOperations"), bytes)

    @client.patch(v1("appScreenshots/#{reserved["id"]}"), {
      data: {
        type: "appScreenshots",
        id: reserved["id"],
        attributes: { uploaded: true, sourceFileChecksum: Digest::MD5.hexdigest(bytes) }
      }
    })

    reserved
  end

  def screenshot(id:)
    @client.get(v1("appScreenshots/#{id}")).body["data"]
  end

  # 업로드 순서가 곧 표시 순서가 아니다 — 세트의 관계를 순서대로 다시 쓴다.
  def reorder(set_id:, screenshot_ids:)
    body = { data: screenshot_ids.map { |id| { type: "appScreenshots", id: id } } }
    @client.patch(v1("appScreenshotSets/#{set_id}/relationships/appScreenshots"), body)
  end

  private

  # spaceship 의 tunes 클라이언트는 https://appstoreconnect.apple.com/iris/ 를 base 로 잡고,
  # 리소스 경로는 전부 v1/ 로 시작한다.
  def v1(path)
    "v1/#{path}"
  end

  # ASC 는 200건이 페이지 상한이라 links.next 를 따라가야 전량이 나온다.
  def paged(path, params)
    collected = []
    response = @client.get(path, params)
    loop do
      body = response.body
      collected.concat(body["data"] || [])
      next_url = body.dig("links", "next")
      break unless next_url

      response = @client.get(next_url)
    end
    collected
  end
end

def page_client
  ASCCustomProductPageClient.new(client: authenticated_client)
end

def resolved_app(client)
  bundle_id = bundle_identifier
  app_id = client.app_id(bundle_id: bundle_id)
  abort_with("bundleId #{bundle_id} 로 앱을 못 찾았다 — 키에 이 앱 권한이 있는지 확인해라") unless app_id
  app_id
end

# MARK: - 설정

def pages_path
  File.join(CONFIG_ROOT, "pages.json")
end

def load_pages
  path = pages_path
  abort_with("#{path} 가 없다 — 페이지 구성을 먼저 만들어라") unless File.exist?(path)

  parsed = begin
    JSON.parse(File.read(path))
  rescue JSON::ParserError => error
    abort_with("#{path} 가 JSON 이 아니다 — #{error.message}")
  end

  broken = parsed.filter_map do |page_id, config|
    scenes = config["scenes"] || []
    "#{page_id} — 장면이 #{scenes.size}개다 (#{SCENES_PER_PAGE}개여야 한다)" if scenes.size != SCENES_PER_PAGE
  end
  abort_with(broken.join("\n")) unless broken.empty?
  parsed
end

def save_pages(pages)
  File.write(pages_path, "#{JSON.pretty_generate(pages)}\n")
end

def target_pages(pages, page_option, all_pages)
  if all_pages && page_option
    abort_with("--page 와 --all-pages 는 함께 못 쓴다")
  end
  return pages.keys if all_pages

  abort_with("--page <page_id> 또는 --all-pages 중 하나가 필요하다") unless page_option
  unless pages.key?(page_option)
    abort_with("모르는 페이지: #{page_option} — 아는 것은 #{pages.keys.join(", ")}")
  end
  [page_option]
end

# 로케일 축의 정본은 fastlane/metadata 의 디렉토리 이름(ASC 코드)이다.
def metadata_locales
  Dir.children(METADATA_ROOT).sort.select do |name|
    File.directory?(File.join(METADATA_ROOT, name)) && !NON_LOCALE_METADATA_DIRS.include?(name)
  end
end

def target_locales(locale_option, all_locales)
  return metadata_locales if all_locales

  abort_with("--locale <ASC로케일> 또는 --all-locales 중 하나가 필요하다") unless locale_option
  [locale_option]
end

def asc_page_id(pages, page_id)
  id = pages.dig(page_id, "ascPageId").to_s.strip
  abort_with("#{page_id} 의 ascPageId 가 비었다 — `create` 를 먼저 돌려라") if id.empty?
  id
end

def promotional_text(page_id, locale)
  path = File.join(CONFIG_ROOT, page_id, locale, PROMOTIONAL_TEXT_FILE)
  return nil unless File.exist?(path)

  File.read(path).strip
end

# 위반을 첫 건에서 멈추지 않고 전량 모은다 — 31개 로케일을 한 번에 고치게 한다.
def text_violations(page_ids, locales)
  page_ids.flat_map do |page_id|
    locales.filter_map do |locale|
      text = promotional_text(page_id, locale)
      next "#{page_id}/#{locale} — #{PROMOTIONAL_TEXT_FILE} 이 없거나 비었다" if text.nil? || text.empty?
      next if text.length <= PROMOTIONAL_TEXT_LIMIT

      "#{page_id}/#{locale} — #{text.length}자 (상한 #{PROMOTIONAL_TEXT_LIMIT})"
    end
  end
end

def image_paths(page_id, locale)
  directory = File.join(CONFIG_ROOT, page_id, "images", locale)
  Dir.glob(File.join(directory, "*.png")).sort
end

def image_violations(page_ids, locales)
  page_ids.flat_map do |page_id|
    locales.filter_map do |locale|
      count = image_paths(page_id, locale).size
      next if count == SCENES_PER_PAGE

      "#{page_id}/#{locale} — 이미지가 #{count}장이다 (#{SCENES_PER_PAGE}장이어야 한다)"
    end
  end
end

# MARK: - 서브커맨드

def run_list
  client = page_client
  pages = client.pages(app_id: resolved_app(client))
  if pages.empty?
    puts("맞춤형 제품 페이지가 없다 — `create` 로 만들어라")
    return
  end

  puts(format("%-38s  %-20s  %s", "ID", "NAME", "VISIBLE"))
  pages.each do |entry|
    attributes = entry["attributes"] || {}
    puts(format("%-38s  %-20s  %s", entry["id"], attributes["name"], attributes["visible"]))
  end
  puts("\n#{pages.size}건")
end

def run_create
  pages = load_pages
  client = page_client
  app_id = resolved_app(client)
  primary_locale = client.primary_locale(app_id: app_id)
  existing = client.pages(app_id: app_id).each_with_object({}) do |entry, collected|
    collected[entry.dig("attributes", "name")] = entry["id"]
  end

  pages.each do |page_id, config|
    if !config["ascPageId"].to_s.strip.empty?
      puts("· #{page_id} — 이미 #{config["ascPageId"]}")
      next
    end
    if existing.key?(page_id)
      config["ascPageId"] = existing[page_id]
      puts("· #{page_id} — ASC 에 이미 있다, id 만 채운다 (#{existing[page_id]})")
      next
    end
    created = client.create_page(app_id: app_id, name: page_id, primary_locale: primary_locale)
    config["ascPageId"] = created["id"]
    puts("✓ #{page_id} → #{created["id"]}")
  end

  save_pages(pages)
  puts("\n#{pages_path} 에 ascPageId 를 채웠다")
end

def print_text_plan(page_ids, locales, existing_by_page)
  puts(format("%-14s  %-10s  %-8s  %s", "PAGE", "LOCALE", "ACTION", "길이"))
  page_ids.each do |page_id|
    locales.each do |locale|
      text = promotional_text(page_id, locale).to_s
      action = existing_by_page[page_id].key?(locale) ? "PATCH" : "POST"
      puts(format("%-14s  %-10s  %-8s  %d", page_id, locale, action, text.length))
    end
  end
end

def run_push_text(page_option, all_pages, locale_option, all_locales, dry_run)
  pages = load_pages
  page_ids = target_pages(pages, page_option, all_pages)
  locales = target_locales(locale_option, all_locales)

  violations = text_violations(page_ids, locales)
  unless violations.empty?
    abort_with("원고가 ASC 제약을 어겼다 — #{violations.size}건\n\n#{violations.map { |line| "  #{line}" }.join("\n")}")
  end

  client = page_client
  versions = page_ids.to_h { |page_id| [page_id, client.version(page_id: asc_page_id(pages, page_id))["id"]] }
  existing_by_page = versions.transform_values { |version_id| client.localizations(version_id: version_id) }
  print_text_plan(page_ids, locales, existing_by_page)

  if dry_run
    puts("\n--dry-run — 아무것도 올리지 않았다")
    return
  end

  page_ids.each do |page_id|
    print("▶︎ [#{page_id}] ")
    locales.each do |locale|
      text = promotional_text(page_id, locale)
      entry = existing_by_page[page_id][locale]
      if entry
        client.update_localization(id: entry["id"], promotional_text: text)
      else
        client.create_localization(version_id: versions[page_id], locale: locale, promotional_text: text)
      end
      print(".")
    end
    puts
  end

  missing = page_ids.flat_map do |page_id|
    filled = client.localizations(version_id: versions[page_id]).keys
    (locales - filled).map { |locale| "#{page_id}/#{locale}" }
  end
  abort_with("올린 뒤 재조회했는데 #{missing.size}개가 비었다: #{missing.join(" ")}") unless missing.empty?
  puts("✓ #{page_ids.size}페이지 × #{locales.size}개 로케일 — ASC 재조회로 확인됨")
end

def print_image_plan(page_ids, locales)
  puts(format("%-14s  %-10s  %-6s  %s", "PAGE", "LOCALE", "장수", "합계(KB)"))
  page_ids.each do |page_id|
    locales.each do |locale|
      paths = image_paths(page_id, locale)
      kilobytes = paths.sum { |path| File.size(path) } / 1024
      puts(format("%-14s  %-10s  %-6d  %d", page_id, locale, paths.size, kilobytes))
    end
  end
end

# ASC 가 자산을 처리하는 데 시간이 걸린다. COMPLETE 가 되기 전에 넘어가면 콘솔에 안 붙은 채로 남는다.
def await_delivery(client, screenshot_id)
  30.times do
    state = client.screenshot(id: screenshot_id).dig("attributes", "assetDeliveryState") || {}
    return true if state["state"] == "COMPLETE"

    if state["state"] == "FAILED"
      messages = (state["errors"] || []).map { |error| [error["code"], error["description"]].compact.join(" - ") }
      warn("    ✗ 업로드 실패 — #{messages.join(" / ")}")
      return false
    end
    sleep(2)
  end
  warn("    ✗ 60초 안에 COMPLETE 가 안 됐다 (screenshot #{screenshot_id})")
  false
end

# 기존 스크린샷을 지우고 다시 올린다 — 안 지우면 6장 위에 6장이 더 쌓인다.
def replace_screenshots(client, set_id, paths)
  client.screenshots(set_id: set_id).each { |entry| client.delete_screenshot(id: entry["id"]) }

  uploaded = paths.map { |path| client.upload_screenshot(set_id: set_id, path: path) }
  delivered = uploaded.map { |entry| await_delivery(client, entry["id"]) }
  client.reorder(set_id: set_id, screenshot_ids: uploaded.map { |entry| entry["id"] })
  delivered.all?
end

def run_push_images(page_option, all_pages, locale_option, all_locales, dry_run)
  pages = load_pages
  page_ids = target_pages(pages, page_option, all_pages)
  locales = target_locales(locale_option, all_locales)

  violations = image_violations(page_ids, locales)
  unless violations.empty?
    abort_with(
      "합성한 이미지가 라인업과 다르다 — #{violations.size}건\n\n" \
      "#{violations.map { |line| "  #{line}" }.join("\n")}\n\n" \
      "compose-cpp-screenshots.py 를 먼저 돌려라"
    )
  end

  print_image_plan(page_ids, locales)
  if dry_run
    puts("\n--dry-run — 아무것도 올리지 않았다")
    return
  end

  client = page_client
  failed = []
  page_ids.each do |page_id|
    version_id = client.version(page_id: asc_page_id(pages, page_id))["id"]
    existing = client.localizations(version_id: version_id)
    orphans = locales - existing.keys
    unless orphans.empty?
      abort_with("이미지가 매달릴 로케일이 ASC 에 없다: #{page_id} — #{orphans.join(" ")}\n\npush-text 를 먼저 돌려라")
    end

    puts("▶︎ [#{page_id}]")
    locales.each do |locale|
      set = client.screenshot_set(localization_id: existing[locale]["id"])
      ok = begin
        replace_screenshots(client, set["id"], image_paths(page_id, locale))
      rescue StandardError => error
        warn("    ✗ #{locale} — #{error.class}: #{error.message}")
        false
      end
      failed << "#{page_id}/#{locale}" unless ok
      print(ok ? "." : "x")
    end
    puts
  end

  abort_with("실패한 페이지·로케일 #{failed.size}개: #{failed.join(" ")}") unless failed.empty?
  puts("✓ #{page_ids.size}페이지 × #{locales.size}개 로케일 × #{SCENES_PER_PAGE}장 — 전부 COMPLETE")
end

# MARK: - 인자 파싱

def option_value(argv, name)
  index = argv.index(name)
  return nil unless index

  argv[index + 1]
end

def main(argv)
  command = argv.shift
  dry_run = argv.delete("--dry-run") ? true : false
  all_pages = argv.delete("--all-pages") ? true : false
  all_locales = argv.delete("--all-locales") ? true : false
  page_option = option_value(argv, "--page")
  locale_option = option_value(argv, "--locale")

  case command
  when "list" then run_list
  when "create" then run_create
  when "push-text" then run_push_text(page_option, all_pages, locale_option, all_locales, dry_run)
  when "push-images" then run_push_images(page_option, all_pages, locale_option, all_locales, dry_run)
  else
    abort_with(File.read(__FILE__).lines[3..14].map { |line| line.sub(/^# ?/, "") }.join)
  end
end

main(ARGV) if $PROGRAM_NAME == __FILE__
