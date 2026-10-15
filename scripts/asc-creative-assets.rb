#!/usr/bin/env ruby
# frozen_string_literal: true

# App Store 제품 페이지 헤더(21:9)·검색 결과(3:2) 크리에이티브 에셋을 Asset Library 에 올려
# 앱 버전 로케일에 placement 로 건다.
#
# usage (PATH 는 docs/appstore-connect-operations.md §1, 자격증명은 secret/README.md):
#   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
#   bundle exec ruby scripts/asc-creative-assets.rb list [--version <x.y.z>]
#   bundle exec ruby scripts/asc-creative-assets.rb push (--locale <ASC로케일>|--all-locales) [--version <x.y.z>] [--dry-run]
#
# --version 을 생략하면 PREPARE_FOR_SUBMISSION 인 iOS 버전 하나를 고른다.
# placement 는 수정이 안 된다 — 교체는 같은 type 의 기존 placement 를 지우고 새로 만든다.

require "json"
require "spaceship"

REQUIRED_ENV = {
  "ASC_KEY_ID" => "App Store Connect > 사용자 및 액세스 > 통합에서 발급한 키 ID",
  "ASC_ISSUER_ID" => "같은 화면의 Issuer ID",
  "ASC_KEY_CONTENT" => "AuthKey_<키ID>.p8 를 base64 로 인코딩한 값 — base64 -i AuthKey_<키ID>.p8"
}.freeze

SECRET_KEYS = %w[key_id issuer_id key_filepath].freeze

ROOT = File.expand_path("..", __dir__)
CONFIG_ROOT = ENV["CREATIVE_CONFIG_ROOT"] || File.join(ROOT, "fastlane", "creative_assets")
METADATA_ROOT = File.join(ROOT, "fastlane", "metadata")

PLACEMENT_GROUP = "DEFAULT_PROFILE"
ASSET_CATEGORY = "CREATIVE_ASSETS"
EDITABLE_VERSION_STATE = "PREPARE_FOR_SUBMISSION"
# 이미지 처리가 끝난 상태. 버전 상태와 이름이 같지만 이미지 리소스의 값이다
ASSET_READY_STATE = "PREPARE_FOR_SUBMISSION"

# 파일 하나 = placement 하나. 규격은 appAssetLibraryRefData 의 imageSpecs 에서 옮겼다.
PLACEMENTS = [
  {
    name: "header",
    file: "header.png",
    type: "PRODUCT_PAGE_HEADER_ASSET",
    spec_id: "1eb43b80-e0b7-4d96-bd32-47a42a8c5fed",
    width: 3840..3840,
    height: 1646..1646
  },
  {
    name: "search",
    file: "search.png",
    type: "APP_STORE_SEARCH_RESULTS_ASSET",
    spec_id: "d2ffa3b7-6c55-5cdf-8512-229d92791333",
    width: 1920..3840,
    height: 1280..2560
  }
].freeze

# deliver 가 로케일이 아닌 용도로 쓰는 하위 디렉토리 (fastlane/Fastfile 과 같은 목록)
NON_LOCALE_METADATA_DIRS = %w[
  review_information
  trade_representative_contact_information
  app_clip_review_information
].freeze

PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
PNG_ALPHA_COLOR_TYPES = [4, 6].freeze

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

class ASCCreativeAssetClient
  def initialize(client:)
    @client = client
  end

  def app_id(bundle_id:)
    apps = @client.get(v1("apps"), { "filter[bundleId]" => bundle_id }).body["data"] || []
    apps.first&.dig("id")
  end

  def ios_versions(app_id:)
    paged(v1("apps/#{app_id}/appStoreVersions"), { "filter[platform]" => "IOS", "limit" => 200 })
  end

  def asset_library_id(app_id:)
    @client.get(v1("apps/#{app_id}/assetLibrary")).body.dig("data", "id")
  end

  def ref_data
    @client.get(v1("appAssetLibraryRefData")).body.dig("data", 0, "attributes") || {}
  end

  def version_localizations(version_id:)
    paged(
      v1("appStoreVersions/#{version_id}/appStoreVersionLocalizations"), { "limit" => 200 }
    ).each_with_object({}) do |entry, collected|
      locale = entry.dig("attributes", "locale")
      collected[locale] = entry if locale
    end
  end

  # include=image 를 안 주면 relationships 에 링크만 오고 image id 가 비어 있다.
  def placements(localization_id:)
    paged(
      v1("appStoreVersionLocalizations/#{localization_id}/placements"),
      { "include" => "image", "limit" => 200 }
    )
  end

  # 예약(POST) → 바이너리 PUT → uploaded PATCH 3단계. Asset Library 는 체크섬을 안 받는다.
  def upload_image(library_id:, path:, reference_name:)
    bytes = File.binread(path)
    reserved = @client.post(v1("appAssetLibraryImages"), {
      data: {
        type: "appAssetLibraryImages",
        attributes: {
          category: ASSET_CATEGORY,
          fileName: File.basename(path),
          fileSize: bytes.bytesize,
          referenceName: reference_name
        },
        relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: library_id } } }
      }
    }).body["data"]

    Spaceship::ConnectAPI::FileUploader.upload(reserved.dig("attributes", "uploadOperations"), bytes)

    @client.patch(v1("appAssetLibraryImages/#{reserved["id"]}"), {
      data: { type: "appAssetLibraryImages", id: reserved["id"], attributes: { uploaded: true } }
    })

    reserved
  end

  def image(id:)
    @client.get(v1("appAssetLibraryImages/#{id}")).body["data"]
  end

  def create_placement(localization_id:, image_id:, placement_type:)
    @client.post(v1("appAssetLibraryPlacements"), {
      data: {
        type: "appAssetLibraryPlacements",
        attributes: { placementType: placement_type, placementGroup: PLACEMENT_GROUP },
        relationships: {
          image: { data: { type: "appAssetLibraryImages", id: image_id } },
          appStoreVersionLocalization: {
            data: { type: "appStoreVersionLocalizations", id: localization_id }
          }
        }
      }
    }).body["data"]
  end

  def delete_placement(id:)
    @client.delete(v1("appAssetLibraryPlacements/#{id}"))
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

def asset_client
  ASCCreativeAssetClient.new(client: authenticated_client)
end

def resolved_app(client)
  bundle_id = bundle_identifier
  app_id = client.app_id(bundle_id: bundle_id)
  abort_with("bundleId #{bundle_id} 로 앱을 못 찾았다 — 키에 이 앱 권한이 있는지 확인해라") unless app_id
  app_id
end

def resolved_version(client, app_id, version_option)
  versions = client.ios_versions(app_id: app_id)
  if version_option
    found = versions.find { |entry| entry.dig("attributes", "versionString") == version_option }
    abort_with("iOS 버전 #{version_option} 이 ASC 에 없다") unless found
    return found
  end

  editable = versions.select { |entry| entry.dig("attributes", "appStoreState") == EDITABLE_VERSION_STATE }
  return editable.first if editable.size == 1

  listed = versions.map { |entry| "#{entry.dig("attributes", "versionString")}(#{entry.dig("attributes", "appStoreState")})" }
  abort_with(
    "#{EDITABLE_VERSION_STATE} 인 iOS 버전이 #{editable.size}개다 — --version 으로 골라라\n\n  #{listed.join(" ")}"
  )
end

# 하드코딩한 spec 이 ASC 쪽에서 바뀌었으면 올리기 전에 멈춘다.
def spec_drift(ref_data)
  specs = (ref_data["imageSpecs"] || []).to_h { |spec| [spec["specId"], spec] }
  mappings = (ref_data["placementTypes"] || []).to_h do |entry|
    group = (entry["specMappings"] || []).find { |mapping| mapping["placementGroupId"] == PLACEMENT_GROUP }
    [entry["placementTypeId"], group ? group["specs"] : []]
  end

  PLACEMENTS.filter_map do |placement|
    spec = specs[placement[:spec_id]]
    next "#{placement[:name]} — spec #{placement[:spec_id]} 이 refData 에 없다" unless spec
    unless (mappings[placement[:type]] || []).include?(placement[:spec_id])
      next "#{placement[:name]} — spec 이 #{placement[:type]}/#{PLACEMENT_GROUP} 에 안 걸려 있다"
    end

    dimensions = spec["dimensions"] || {}
    width = dimensions["minWidth"]..dimensions["maxWidth"]
    height = dimensions["minHeight"]..dimensions["maxHeight"]
    next if width == placement[:width] && height == placement[:height]

    "#{placement[:name]} — 규격이 #{width}×#{height} 로 바뀌었다 (스크립트는 #{placement[:width]}×#{placement[:height]})"
  end
end

# MARK: - 로케일·이미지 가드

# 로케일 축의 정본은 fastlane/metadata 의 디렉토리 이름(ASC 코드)이다.
def metadata_locales
  Dir.children(METADATA_ROOT).sort.select do |name|
    File.directory?(File.join(METADATA_ROOT, name)) && !NON_LOCALE_METADATA_DIRS.include?(name)
  end
end

def target_locales(locale_option, all_locales)
  abort_with("--locale 와 --all-locales 는 함께 못 쓴다") if all_locales && locale_option
  return metadata_locales if all_locales

  abort_with("--locale <ASC로케일> 또는 --all-locales 중 하나가 필요하다") unless locale_option
  unless metadata_locales.include?(locale_option)
    abort_with("모르는 로케일: #{locale_option} — ASC 코드는 fastlane/metadata/README.md 에 있다")
  end
  [locale_option]
end

def image_path(locale, placement)
  File.join(CONFIG_ROOT, "images", locale, placement[:file])
end

# IHDR 는 시그니처 바로 뒤 첫 청크로 고정이다. 팔레트 PNG 의 tRNS 투명도까지는 보지 않는다 —
# 합성기는 RGB 로만 저장한다.
def png_header(path)
  bytes = File.binread(path, 33) || ""
  return nil unless bytes.start_with?(PNG_SIGNATURE) && bytes.byteslice(12, 4) == "IHDR"

  width, height = bytes.byteslice(16, 8).unpack("NN")
  { width: width, height: height, color_type: bytes.getbyte(25) }
end

def image_violation(locale, placement)
  path = image_path(locale, placement)
  label = "#{locale}/#{placement[:file]}"
  return "#{label} — 파일이 없다" unless File.exist?(path)

  header = png_header(path)
  return "#{label} — PNG 가 아니다" unless header
  unless placement[:width].cover?(header[:width]) && placement[:height].cover?(header[:height])
    return "#{label} — #{header[:width]}×#{header[:height]} (규격 #{placement[:width]}×#{placement[:height]})"
  end
  if placement[:height].min != placement[:height].max && header[:width] * 2 != header[:height] * 3
    return "#{label} — #{header[:width]}×#{header[:height]} 이 3:2 가 아니다"
  end
  return "#{label} — 알파 채널이 있다" if PNG_ALPHA_COLOR_TYPES.include?(header[:color_type])

  nil
end

# 위반을 첫 건에서 멈추지 않고 전량 모은다 — 31개 로케일을 한 번에 고치게 한다.
def image_violations(locales)
  locales.flat_map { |locale| PLACEMENTS.filter_map { |placement| image_violation(locale, placement) } }
end

# MARK: - 조회

def current_placements(client, localization_id)
  client.placements(localization_id: localization_id).each_with_object({}) do |entry, collected|
    type = entry.dig("attributes", "placementType")
    collected[type] = entry if PLACEMENTS.any? { |placement| placement[:type] == type }
  end
end

def placement_image_id(entry)
  entry&.dig("relationships", "image", "data", "id")
end

def run_list(version_option)
  client = asset_client
  version = resolved_version(client, resolved_app(client), version_option)
  attributes = version["attributes"] || {}
  puts("버전 #{attributes["versionString"]} (#{attributes["appStoreState"]})\n\n")

  puts(format("%-10s  %-40s  %s", "LOCALE", "HEADER", "SEARCH"))
  client.version_localizations(version_id: version["id"]).sort.each do |locale, localization|
    current = current_placements(client, localization["id"])
    cells = PLACEMENTS.map { |placement| placement_image_id(current[placement[:type]]) || "-" }
    puts(format("%-10s  %-40s  %s", locale, *cells))
  end
end

# MARK: - 올리기

# Asset Library 는 처리를 마치면 PREPARE_FOR_SUBMISSION 이 된다. 그 전에 placement 를 걸면 거부된다.
def await_processed(client, image_id)
  30.times do
    attributes = client.image(id: image_id)["attributes"] || {}
    return attributes if attributes["state"] == ASSET_READY_STATE

    if attributes["state"] == "FAILED"
      details = (attributes["stateDetails"] || []).map { |detail| [detail["code"], detail["description"]].compact.join(" - ") }
      warn("    ✗ 처리 실패 — #{details.join(" / ")}")
      return nil
    end
    sleep(2)
  end
  warn("    ✗ 60초 안에 #{ASSET_READY_STATE} 가 안 됐다 (image #{image_id})")
  nil
end

# 새 이미지가 처리·spec 대조를 통과한 뒤에만 기존 placement 를 지운다 — 그 전에 끊기면 이전 이미지가 남는다.
# 지운 뒤 생성이 실패하면 그 자리가 비고, 실패 목록을 다시 돌리면 신규로 채워진다. 교체로 빠진 이전 이미지는 지우지 않는다.
def replace_placement(client, library_id, locale, localization_id, existing, placement)
  uploaded = client.upload_image(
    library_id: library_id,
    path: image_path(locale, placement),
    reference_name: "creative-#{locale}-#{placement[:name]}"
  )
  processed = await_processed(client, uploaded["id"])
  return nil unless processed

  if processed["specId"] != placement[:spec_id]
    warn("    ✗ #{locale}/#{placement[:name]} — ASC 가 spec #{processed["specId"]} 로 판정했다 (기대 #{placement[:spec_id]})")
    return nil
  end

  client.delete_placement(id: existing["id"]) if existing
  client.create_placement(localization_id: localization_id, image_id: uploaded["id"], placement_type: placement[:type])
  uploaded["id"]
end

def print_push_plan(locales, current_by_locale)
  puts(format("%-10s  %-8s  %-8s  %s", "LOCALE", "PLACE", "ACTION", "크기(KB)"))
  locales.each do |locale|
    current = current_by_locale[locale]
    PLACEMENTS.each do |placement|
      action = if current.nil? then "로케일없음"
               elsif current.key?(placement[:type]) then "교체"
               else "신규"
               end
      kilobytes = File.size(image_path(locale, placement)) / 1024
      puts(format("%-10s  %-8s  %-8s  %d", locale, placement[:name], action, kilobytes))
    end
  end
end

def print_verification(client, locales, localizations, uploaded_ids)
  puts(format("\n%-10s  %-8s  %-40s  %s", "LOCALE", "PLACE", "IMAGE", "대조"))
  locales.filter_map do |locale|
    localization = localizations[locale]
    next unless localization

    current = current_placements(client, localization["id"])
    PLACEMENTS.filter_map do |placement|
      actual = placement_image_id(current[placement[:type]])
      expected = uploaded_ids[[locale, placement[:name]]]
      matched = expected && actual == expected
      puts(format("%-10s  %-8s  %-40s  %s", locale, placement[:name], actual || "-", matched ? "✓" : "✗"))
      "#{locale}/#{placement[:name]}" unless matched
    end
  end.flatten
end

def run_push(locale_option, all_locales, version_option, dry_run)
  locales = target_locales(locale_option, all_locales)

  violations = image_violations(locales)
  unless violations.empty?
    abort_with(
      "합성한 이미지가 규격과 다르다 — #{violations.size}건\n\n" \
      "#{violations.map { |line| "  #{line}" }.join("\n")}\n\n" \
      "compose-creative-assets.py 를 먼저 돌려라"
    )
  end

  client = asset_client
  app_id = resolved_app(client)
  drift = spec_drift(client.ref_data)
  abort_with("ASC 의 에셋 규격이 스크립트와 다르다\n\n#{drift.map { |line| "  #{line}" }.join("\n")}") unless drift.empty?

  version = resolved_version(client, app_id, version_option)
  puts("버전 #{version.dig("attributes", "versionString")} (#{version.dig("attributes", "appStoreState")})\n\n")
  localizations = client.version_localizations(version_id: version["id"])
  current_by_locale = locales.filter_map do |locale|
    localization = localizations[locale]
    [locale, current_placements(client, localization["id"])] if localization
  end.to_h
  print_push_plan(locales, current_by_locale)

  if dry_run
    puts("\n--dry-run — 아무것도 올리지 않았다")
    return
  end

  library_id = client.asset_library_id(app_id: app_id)
  abort_with("앱의 Asset Library 를 못 찾았다") unless library_id

  missing_locales = locales - localizations.keys
  failed = []
  uploaded_ids = {}
  (locales - missing_locales).each do |locale|
    print("▶︎ #{locale} ")
    current = current_by_locale[locale]
    PLACEMENTS.each do |placement|
      image_id = begin
        replace_placement(client, library_id, locale, localizations[locale]["id"], current[placement[:type]], placement)
      rescue StandardError => error
        warn("    ✗ #{locale}/#{placement[:name]} — #{error.class}: #{error.message}")
        nil
      end
      uploaded_ids[[locale, placement[:name]]] = image_id if image_id
      failed << "#{locale}/#{placement[:name]}" unless image_id
      print(image_id ? "." : "x")
    end
    puts
  end

  unverified = print_verification(client, locales, localizations, uploaded_ids) - failed
  problems = []
  problems << "버전에 로케일이 없다 #{missing_locales.size}개: #{missing_locales.join(" ")}" unless missing_locales.empty?
  problems << "올리기 실패 #{failed.size}개: #{failed.join(" ")}" unless failed.empty?
  problems << "재조회 불일치 #{unverified.size}개: #{unverified.join(" ")}" unless unverified.empty?
  abort_with("\n#{problems.join("\n")}") unless problems.empty?
  puts("\n✓ #{locales.size}개 로케일 × #{PLACEMENTS.size}종 — ASC 재조회로 확인됨")
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
  all_locales = argv.delete("--all-locales") ? true : false
  locale_option = option_value(argv, "--locale")
  version_option = option_value(argv, "--version")

  case command
  when "list" then run_list(version_option)
  when "push" then run_push(locale_option, all_locales, version_option, dry_run)
  else
    abort_with(File.read(__FILE__).lines[3..12].map { |line| line.sub(/^# ?/, "") }.join)
  end
end

main(ARGV) if $PROGRAM_NAME == __FILE__
