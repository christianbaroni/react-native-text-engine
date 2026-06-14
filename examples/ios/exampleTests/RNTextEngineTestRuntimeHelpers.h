#import <memory>
#import <string>

#import <jsi/jsi.h>

namespace rntextengine::testhelpers {

class StringBuffer final : public facebook::jsi::Buffer {
 public:
  explicit StringBuffer(std::string source) : source_(std::move(source)) {}

  size_t size() const override
  {
    return source_.size();
  }

  const uint8_t *data() const override
  {
    return reinterpret_cast<const uint8_t *>(source_.data());
  }

 private:
  std::string source_;
};

static inline std::string runtimeHandleTrackingSource()
{
  return R"(
    (() => {
      const preparedHandles = new Set();
      const glyphFieldHandles = new Set();

      const prepare = globalThis.__RNTextEnginePrepare;
      const prepareBatch = globalThis.__RNTextEnginePrepareBatch;
      const release = globalThis.__RNTextEngineRelease;
      const releaseMany = globalThis.__RNTextEngineReleaseMany;
      const createGlyphField = globalThis.__RNTextEngineCreateGlyphField;
      const releaseGlyphField = globalThis.__RNTextEngineReleaseGlyphField;

      globalThis.__RNTextEnginePrepare = function (...args) {
        const handle = prepare(...args);
        preparedHandles.add(handle);
        return handle;
      };

      globalThis.__RNTextEnginePrepareBatch = function (...args) {
        const handles = prepareBatch(...args);
        for (let index = 0; index < handles.length; index += 1) {
          preparedHandles.add(handles[index]);
        }
        return handles;
      };

      globalThis.__RNTextEngineRelease = function (handle) {
        preparedHandles.delete(handle);
        return release(handle);
      };

      globalThis.__RNTextEngineReleaseMany = function (handles) {
        if (handles) {
          for (let index = 0; index < handles.length; index += 1) {
            preparedHandles.delete(handles[index]);
          }
        }
        return releaseMany(handles);
      };

      globalThis.__RNTextEngineCreateGlyphField = function (...args) {
        const handle = createGlyphField(...args);
        glyphFieldHandles.add(handle);
        return handle;
      };

      globalThis.__RNTextEngineReleaseGlyphField = function (handle) {
        glyphFieldHandles.delete(handle);
        return releaseGlyphField(handle);
      };

      globalThis.__RNTextEngineReleaseTrackedTestHandles = function () {
        const glyphHandles = Array.from(glyphFieldHandles);
        glyphFieldHandles.clear();
        for (let index = 0; index < glyphHandles.length; index += 1) {
          releaseGlyphField(glyphHandles[index]);
        }

        const handles = Array.from(preparedHandles);
        preparedHandles.clear();
        if (handles.length === 1) release(handles[0]);
        else if (handles.length > 1) releaseMany(handles);
      };
    })();
  )";
}

static inline void installRuntimeHandleTracking(facebook::jsi::Runtime& runtime)
{
  runtime.evaluateJavaScript(
      std::make_unique<StringBuffer>(runtimeHandleTrackingSource()),
      "RNTextEngineTestRuntimeTracking.js");
}

static inline void releaseTrackedRuntimeHandles(facebook::jsi::Runtime& runtime)
{
  runtime.evaluateJavaScript(
      std::make_unique<StringBuffer>("globalThis.__RNTextEngineReleaseTrackedTestHandles?.();"),
      "RNTextEngineTestRuntimeCleanup.js");
}

} // namespace rntextengine::testhelpers
