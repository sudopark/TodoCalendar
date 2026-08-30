#!/usr/bin/env ruby
# frozen_string_literal: true

# App Store Connect 앱 내 이벤트(In-App Event)를 조회하고 갱신한다.
#
# usage (PATH 는 docs/appstore-connect-operations.md §1, 자격증명은 secret/README.md):
#   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
#   bundle exec ruby scripts/asc-in-app-event.rb list
#   bundle exec ruby scripts/asc-in-app-event.rb show <event-id>
#   bundle exec ruby scripts/asc-in-app-event.rb set-badge <event-id> <BADGE>
#   bundle exec ruby scripts/asc-in-app-event.rb push-text --event <id> (--locale <ASC로케일>|--all-locales) [--dry-run]
#   bundle exec ruby scripts/asc-in-app-event.rb push-images --event <id> (--locale <ASC로케일>|--all-locales) [--dry-run]
#
# fastlane deliver 는 In-App Events 를 모른다 (deliver 전체에 app_event 키가 없다).
# 그래서 lane 이 아니라 spaceship 의 raw ASC 클라이언트를 직접 쓴다.

require "json"
require "spaceship"

BADGES = %w[
  LIVE_EVENT PREMIERE CHALLENGE COMPETITION NEW_SEASON MAJOR_UPDATE SPECIAL_EVENT
].freeze

# 게시된 이벤트를 덮어쓰는 중일 수 있어 경고 대상이 되는 상태
PUBLISHED_STATES = %w[PUBLISHED PAST ARCHIVED].freeze

REQUIRED_ENV = {
  "ASC_KEY_ID" => "App Store Connect > 사용자 및 액세스 > 통합에서 발급한 키 ID",
  "ASC_ISSUER_ID" => "같은 화면의 Issuer ID",
  "ASC_KEY_CONTENT" => "AuthKey_<키ID>.p8 를 base64 로 인코딩한 값 — base64 -i AuthKey_<키ID>.p8"
}.freeze

SECRET_KEYS = %w[key_id issuer_id key_filepath].freeze

ROOT = File.expand_path("..", __dir__)
EVENT_ROOT = File.join(ROOT, "fastlane", "in_app_events")
METADATA_ROOT = File.join(ROOT, "fastlane", "metadata")

# 파일명 = ASC 필드. 상한은 코드포인트 수 기준이라 바이트로 세면 CJK 가 전부 위반이 된다.
FIELDS = [
  { file: "name", attribute: "name", limit: 30 },
  { file: "short_description", attribute: "shortDescription", limit: 50 },
  { file: "long_description", attribute: "longDescription", limit: 120 }
].freeze

# 로케일당 두 슬롯. 파일명은 compose-event-images.py 의 산출물 이름과 짝이다.
IMAGE_SLOTS = [
  { file: "event-card_1920x1080.png", asset_type: "EVENT_CARD" },
  { file: "event-detail_1080x1920.png", asset_type: "EVENT_DETAILS_PAGE" }
].freeze

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

class ASCEventClient
  def initialize(client:)
    @client = client
  end

  def app_id(bundle_id:)
    apps = @client.get(v1("apps"), { "filter[bundleId]" => bundle_id }).body["data"] || []
    apps.first&.dig("id")
  end

  # appEvents 는 컬렉션 조회를 안 받는다(GET_COLLECTION 불가) — 앱 관계로 타고 들어간다.
  def events(app_id:)
    paged(v1("apps/#{app_id}/appEvents"), { "limit" => 200 })
  end

  def event(id:)
    @client.get(v1("appEvents/#{id}")).body["data"]
  end

  def update_badge(id:, badge:)
    body = { data: { type: "appEvents", id: id, attributes: { badge: badge } } }
    @client.patch(v1("appEvents/#{id}"), body).body["data"]
  end

  def localizations(event_id:)
    paged(v1("appEvents/#{event_id}/localizations"), { "limit" => 50 })
      .each_with_object({}) do |entry, collected|
        locale = entry.dig("attributes", "locale")
        collected[locale] = entry if locale
      end
  end

  def create_localization(event_id:, locale:, attributes:)
    body = {
      data: {
        type: "appEventLocalizations",
        attributes: attributes.merge(locale: locale),
        relationships: { appEvent: { data: { type: "appEvents", id: event_id } } }
      }
    }
    @client.post(v1("appEventLocalizations"), body).body["data"]
  end

  # PATCH 에는 locale 을 싣지 않는다 — 생성 시점에만 정해지는 값이다.
  def update_localization(id:, attributes:)
    body = { data: { type: "appEventLocalizations", id: id, attributes: attributes } }
    @client.patch(v1("appEventLocalizations/#{id}"), body).body["data"]
  end

  def screenshots(localization_id:)
    paged(v1("appEventLocalizations/#{localization_id}/appEventScreenshots"), { "limit" => 50 })
  end

  def delete_screenshot(id:)
    @client.delete(v1("appEventScreenshots/#{id}"))
  end

  # 예약(POST) → 바이너리 PUT → uploaded PATCH commit 3단계.
  # AppScreenshot.create 와 같은 절차지만 commit 페이로드가 다르다 — appEventScreenshots 에는
  # sourceFileChecksum 이 없어서(appScreenshots 전용) 함께 보내면 요청 전체가 거부된다.
  def upload_screenshot(localization_id:, path:, asset_type:)
    bytes = File.binread(path)
    reserved = @client.post(v1("appEventScreenshots"), {
      data: {
        type: "appEventScreenshots",
        attributes: {
          fileSize: bytes.bytesize,
          fileName: File.basename(path),
          appEventAssetType: asset_type
        },
        relationships: {
          appEventLocalization: { data: { type: "appEventLocalizations", id: localization_id } }
        }
      }
    }).body["data"]

    Spaceship::ConnectAPI::FileUploader.upload(reserved.dig("attributes", "uploadOperations"), bytes)

    @client.patch(v1("appEventScreenshots/#{reserved["id"]}"), {
      data: {
        type: "appEventScreenshots",
        id: reserved["id"],
        attributes: { uploaded: true }
      }
    }).body["data"]

    reserved
  end

  def screenshot(id:)
    @client.get(v1("appEventScreenshots/#{id}")).body["data"]
  end

  private

  # spaceship 의 tunes 클라이언트는 https://appstoreconnect.apple.com/iris/ 를 base 로 잡고,
  # 리소스 경로는 전부 v1/ 로 시작한다 (gem 의 tunes.rb 가 모든 호출에 Version::V1 을 붙인다).
  # 접두를 빼면 "path does not match a defined resource type" 로 돌아온다.
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

def event_client
  ASCEventClient.new(client: authenticated_client)
end

def resolved_app(client)
  bundle_id = bundle_identifier
  app_id = client.app_id(bundle_id: bundle_id)
  abort_with("bundleId #{bundle_id} 로 앱을 못 찾았다 — 키에 이 앱 권한이 있는지 확인해라") unless app_id
  app_id
end

def warn_if_published(attributes)
  state = attributes["eventState"]
  return unless PUBLISHED_STATES.include?(state)

  warn("⚠︎ eventState=#{state} — 이미 게시됐거나 종료된 이벤트다. 덮어쓰는 게 맞는지 확인해라")
end

def run_list
  client = event_client
  events = client.events(app_id: resolved_app(client))
  abort_with("앱 내 이벤트가 없다 — App Store Connect 콘솔에서 먼저 만들어라") if events.empty?

  puts(format("%-14s  %-28s  %-14s  %-16s  %s", "ID", "REFERENCE NAME", "BADGE", "STATE", "PRIMARY"))
  events.each do |entry|
    attributes = entry["attributes"] || {}
    puts(format(
      "%-14s  %-28s  %-14s  %-16s  %s",
      entry["id"],
      attributes["referenceName"],
      attributes["badge"],
      attributes["eventState"],
      attributes["primaryLocale"]
    ))
  end
  puts("\n#{events.size}건")
end

def run_show(event_id)
  client = event_client
  entry = client.event(id: event_id)
  attributes = entry["attributes"] || {}
  locales = client.localizations(event_id: event_id).keys

  attributes.each { |key, value| puts(format("%-28s %s", key, value.inspect)) }
  puts(format("%-28s %d개 — %s", "localizations", locales.size, locales.sort.join(" ")))
  warn_if_published(attributes)
end

def run_set_badge(event_id, badge)
  unless BADGES.include?(badge)
    abort_with("badge 는 다음 7종 중 하나다:\n  #{BADGES.join("\n  ")}")
  end

  client = event_client
  current = client.event(id: event_id)
  warn_if_published(current["attributes"] || {})
  updated = client.update_badge(id: event_id, badge: badge)
  puts("✓ badge → #{updated.dig("attributes", "badge")}")
end

# 로케일 축의 정본은 fastlane/metadata 의 디렉토리 이름(ASC 코드)이다.
def metadata_locales
  Dir.children(METADATA_ROOT).sort.select do |name|
    File.directory?(File.join(METADATA_ROOT, name)) && !NON_LOCALE_METADATA_DIRS.include?(name)
  end
end

def event_directory(event_id)
  path = File.join(EVENT_ROOT, event_id)
  abort_with("#{path} 가 없다 — 이벤트 원고 디렉토리를 먼저 만들어라") unless File.directory?(path)
  path
end

# --event 는 사람이 읽는 디렉토리 슬러그다. ASC 리소스 id 는 event.json 에 따로 있다 —
# 슬러그를 그대로 API 에 넘기면 그런 이벤트가 없다는 응답이 온다.
def asc_event_id(event_dir)
  path = File.join(event_dir, "event.json")
  abort_with("#{path} 가 없다 — ascEventId 를 담을 설정 파일이 필요하다") unless File.exist?(path)

  config = begin
    JSON.parse(File.read(path))
  rescue JSON::ParserError => error
    abort_with("#{path} 가 JSON 이 아니다 — #{error.message}")
  end

  id = config["ascEventId"].to_s.strip
  abort_with("#{path} 의 ascEventId 가 비었다 — `list` 로 확인해 채워라") if id.empty?
  id
end

def read_copy(event_dir, locale)
  FIELDS.each_with_object({}) do |field, collected|
    path = File.join(event_dir, locale, "#{field[:file]}.txt")
    collected[field[:file]] = File.exist?(path) ? File.read(path).strip : nil
  end
end

# 위반을 첫 건에서 멈추지 않고 전량 모은다 — 31개 로케일을 한 번에 고치게 한다.
def copy_violations(event_dir, locales)
  locales.flat_map do |locale|
    copy = read_copy(event_dir, locale)
    FIELDS.filter_map do |field|
      text = copy[field[:file]]
      next "#{locale} #{field[:file]} — 파일이 없거나 비었다" if text.nil? || text.empty?
      next if text.length <= field[:limit]

      "#{locale} #{field[:file]} — #{text.length}자 (상한 #{field[:limit]})"
    end
  end
end

def asc_attributes(copy)
  FIELDS.each_with_object({}) { |field, collected| collected[field[:attribute]] = copy[field[:file]] }
end

def target_locales(event_dir, locale_option, all_locales)
  return metadata_locales if all_locales

  abort_with("--locale <ASC로케일> 또는 --all-locales 중 하나가 필요하다") unless locale_option
  unless File.directory?(File.join(event_dir, locale_option))
    abort_with("#{event_dir}/#{locale_option} 가 없다 — 로케일 코드는 lproj 가 아니라 ASC 코드다 (fastlane/metadata/README.md)")
  end
  [locale_option]
end

def print_text_plan(event_dir, locales, existing)
  puts(format("%-10s  %-8s  %s", "LOCALE", "ACTION", "길이 (name/short/long)"))
  locales.each do |locale|
    copy = read_copy(event_dir, locale)
    lengths = FIELDS.map { |field| copy[field[:file]].to_s.length }.join("/")
    puts(format("%-10s  %-8s  %s", locale, existing.key?(locale) ? "PATCH" : "POST", lengths))
  end
end

def run_push_text(event_id, locale_option, all_locales, dry_run)
  event_dir = event_directory(event_id)
  locales = target_locales(event_dir, locale_option, all_locales)

  violations = copy_violations(event_dir, locales)
  unless violations.empty?
    abort_with("원고가 ASC 제약을 어겼다 — #{violations.size}건\n\n#{violations.map { |line| "  #{line}" }.join("\n")}")
  end

  asc_id = asc_event_id(event_dir)
  client = event_client
  existing = client.localizations(event_id: asc_id)
  print_text_plan(event_dir, locales, existing)

  if dry_run
    puts("\n--dry-run — 아무것도 올리지 않았다")
    return
  end

  locales.each do |locale|
    attributes = asc_attributes(read_copy(event_dir, locale))
    entry = existing[locale]
    if entry
      client.update_localization(id: entry["id"], attributes: attributes)
    else
      client.create_localization(event_id: asc_id, locale: locale, attributes: attributes)
    end
    print(".")
  end
  puts

  filled = client.localizations(event_id: asc_id).keys
  missing = locales - filled
  abort_with("올린 뒤 재조회했는데 #{missing.size}개 로케일이 비었다: #{missing.join(" ")}") unless missing.empty?
  puts("✓ #{locales.size}개 로케일 — ASC 재조회로 확인됨 (전체 #{filled.size}개)")
end

def image_directory(event_id, locale)
  File.join(EVENT_ROOT, event_id, "images", locale)
end

def missing_images(event_id, locales)
  locales.flat_map do |locale|
    IMAGE_SLOTS.filter_map do |slot|
      path = File.join(image_directory(event_id, locale), slot[:file])
      "#{locale} #{slot[:file]} — 없다" unless File.exist?(path)
    end
  end
end

def print_image_plan(event_id, locales, existing, client)
  puts(format("%-10s  %-34s  %-9s  %s", "LOCALE", "FILE", "SIZE(KB)", "기존 슬롯"))
  locales.each do |locale|
    entry = existing[locale]
    occupied = entry ? client.screenshots(localization_id: entry["id"]).map { |s| s.dig("attributes", "appEventAssetType") } : []
    IMAGE_SLOTS.each do |slot|
      path = File.join(image_directory(event_id, locale), slot[:file])
      size = File.exist?(path) ? (File.size(path) / 1024.0).round : 0
      puts(format(
        "%-10s  %-34s  %-9s  %s",
        locale, slot[:file], size,
        occupied.include?(slot[:asset_type]) ? "점유 — 지우고 올린다" : "빔"
      ))
    end
  end
end

# ASC 가 자산을 처리하는 데 시간이 걸린다. COMPLETE 가 되기 전에 다음으로 넘어가면
# 콘솔에 자산이 안 붙은 채로 남는다.
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

def replace_slot(client, localization_id, event_id, locale, slot)
  client.screenshots(localization_id: localization_id)
        .select { |entry| entry.dig("attributes", "appEventAssetType") == slot[:asset_type] }
        .each { |entry| client.delete_screenshot(id: entry["id"]) }

  path = File.join(image_directory(event_id, locale), slot[:file])
  uploaded = client.upload_screenshot(localization_id: localization_id, path: path, asset_type: slot[:asset_type])
  await_delivery(client, uploaded["id"])
end

def run_push_images(event_id, locale_option, all_locales, dry_run)
  event_dir = event_directory(event_id)
  locales = target_locales(event_dir, locale_option, all_locales)

  absent = missing_images(event_id, locales)
  unless absent.empty?
    abort_with("합성한 이미지가 없다 — #{absent.size}건\n\n#{absent.map { |line| "  #{line}" }.join("\n")}\n\ncompose-event-images.py 를 먼저 돌려라")
  end

  asc_id = asc_event_id(event_dir)
  client = event_client
  existing = client.localizations(event_id: asc_id)
  orphans = locales - existing.keys
  unless orphans.empty?
    abort_with("이미지가 매달릴 로케일이 ASC 에 없다: #{orphans.join(" ")}\n\npush-text 를 먼저 돌려라 — 이미지는 로케일에 매달린다")
  end

  print_image_plan(event_id, locales, existing, client)
  if dry_run
    puts("\n--dry-run — 아무것도 올리지 않았다")
    return
  end

  # all? 는 첫 실패에서 멈춰 나머지 슬롯을 건너뛴다 — map 으로 둘 다 시도한 뒤 판정한다.
  # 한 로케일의 예외가 31개 배치를 통째로 끊지 않게 여기서 흡수한다.
  failed = locales.reject do |locale|
    puts("▶︎ [#{locale}]")
    IMAGE_SLOTS.map do |slot|
      begin
        replace_slot(client, existing[locale]["id"], event_id, locale, slot)
      rescue StandardError => error
        warn("    ✗ #{slot[:asset_type]} — #{error.class}: #{error.message}")
        false
      end
    end.all?
  end

  abort_with("실패한 로케일 #{failed.size}개: #{failed.join(" ")}") unless failed.empty?
  verify_images_delivered(client, existing, locales)
end

# 올린 뒤 ASC 를 다시 읽어 자산이 실제로 붙었는지 센다. 예약(AWAITING_UPLOAD)만 만들어지고
# 바이너리가 안 붙어도 슬롯은 "찬" 것처럼 보이므로, 슬롯 수가 아니라 전달 상태를 판정한다.
def verify_images_delivered(client, existing, locales)
  incomplete = locales.flat_map do |locale|
    client.screenshots(localization_id: existing[locale]["id"]).filter_map do |shot|
      state = (shot.dig("attributes", "assetDeliveryState") || {})["state"]
      next if state == "COMPLETE"

      "#{locale} #{shot.dig("attributes", "appEventAssetType")} → #{state}"
    end
  end

  expected = locales.size * IMAGE_SLOTS.size
  unless incomplete.empty?
    abort_with(
      "올린 뒤 재조회했는데 #{incomplete.size}/#{expected} 장이 COMPLETE 가 아니다\n\n" \
      "#{incomplete.first(10).map { |line| "  #{line}" }.join("\n")}"
    )
  end
  puts("✓ #{expected}장 — ASC 재조회로 전부 COMPLETE 확인됨")
end

USAGE = <<~TEXT
  usage:
    bundle exec ruby scripts/asc-in-app-event.rb list
    bundle exec ruby scripts/asc-in-app-event.rb show <event-id>
    bundle exec ruby scripts/asc-in-app-event.rb set-badge <event-id> <BADGE>
    bundle exec ruby scripts/asc-in-app-event.rb push-text --event <id> (--locale <ASC로케일>|--all-locales) [--dry-run]
    bundle exec ruby scripts/asc-in-app-event.rb push-images --event <id> (--locale <ASC로케일>|--all-locales) [--dry-run]
TEXT

# 다음 토큰이 또 다른 플래그면 값이 아니다 — `--event --dry-run` 이 "--dry-run" 을 id 로 삼는 걸 막는다.
def flag_value(args, name)
  index = args.index(name)
  return nil unless index

  value = args[index + 1]
  value&.start_with?("--") ? nil : value
end

subcommand, *rest = ARGV
case subcommand
when "list" then rest.empty? ? run_list : abort_with(USAGE)
when "show" then rest.size == 1 ? run_show(rest[0]) : abort_with(USAGE)
when "set-badge" then rest.size == 2 ? run_set_badge(rest[0], rest[1]) : abort_with(USAGE)
when "push-text", "push-images"
  event_id = flag_value(rest, "--event")
  abort_with(USAGE) unless event_id
  locale = flag_value(rest, "--locale")
  all_locales = rest.include?("--all-locales")
  dry_run = rest.include?("--dry-run")
  if subcommand == "push-text"
    run_push_text(event_id, locale, all_locales, dry_run)
  else
    run_push_images(event_id, locale, all_locales, dry_run)
  end
else abort_with(USAGE)
end
