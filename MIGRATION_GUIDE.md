# Docker Migration Guide

## 🎯 **Migration Overview**

This guide helps you migrate from the old Docker setup to the new improved Docker architecture that eliminates duplication and provides better testing.

## 📊 **What's Changed**

### **Before (Old Setup)**
- ❌ 3 separate Dockerfiles with 70%+ duplicate code
- ❌ Permission issues only caught in CI
- ❌ Manual maintenance of duplicate configurations
- ❌ No local testing before CI pushes

### **After (New Setup)**
- ✅ Generated Dockerfiles with shared patterns
- ✅ Comprehensive local testing catches issues early
- ✅ Automated generation reduces maintenance burden
- ✅ Enhanced CI pipeline with security scanning

## 🚀 **Migration Steps**

### **Phase 1: Test New Setup (Current)**

The new Docker setup is ready for testing. You can use it alongside the old setup:

```bash
# Test new Dockerfiles
./scripts/build-all-images.sh

# Test both old and new (enhanced script)
./scripts/build-and-test-enhanced.sh

# Generate updated Dockerfiles
./scripts/generate-dockerfiles.sh
```

### **Phase 2: Update CI Pipeline**

Replace the current CI workflow with the enhanced version:

```bash
# Backup current CI workflow
cp .github/workflows/ci.yml .github/workflows/ci-legacy.yml

# Use enhanced CI workflow
cp .github/workflows/ci-enhanced.yml .github/workflows/ci.yml
```

**Benefits of Enhanced CI:**
- 🧪 **Docker Testing Job** - Comprehensive Docker image testing
- 🔒 **Security Scanning** - Vulnerability scanning with Trivy
- 📊 **Better Reporting** - Enhanced CI summary and status

### **Phase 3: Replace Dockerfiles**

Once you're confident with the new setup:

```bash
# Backup old Dockerfiles
mkdir docker/legacy
mv docker/Dockerfile.alpine docker/legacy/
mv docker/Dockerfile.optimized docker/legacy/
mv docker/Dockerfile.dev docker/legacy/

# Replace with new Dockerfiles
mv docker/Dockerfile.alpine.new docker/Dockerfile.alpine
mv docker/Dockerfile.optimized.new docker/Dockerfile.optimized
mv docker/Dockerfile.dev.new docker/Dockerfile.dev
```

### **Phase 4: Update Build Scripts**

Update your build scripts to use the new approach:

```bash
# Update build-and-test.sh to use new approach
cp scripts/build-and-test-enhanced.sh scripts/build-and-test.sh

# Or keep both for flexibility
# (enhanced script works with both old and new Dockerfiles)
```

## 🛠️ **New Tools Available**

### **1. Dockerfile Generation**
```bash
# Generate Dockerfiles with shared patterns
./scripts/generate-dockerfiles.sh
```

### **2. Comprehensive Testing**
```bash
# Test all Docker images
./scripts/test-docker-images.sh

# Build and test new images
./scripts/build-all-images.sh

# Test both old and new (transition script)
./scripts/build-and-test-enhanced.sh
```

### **3. Docker Compose Building**
```bash
# Build all variants with Docker Compose
docker-compose -f docker/docker-compose.build.yml build
```

## 📋 **Migration Checklist**

### **Pre-Migration**
- [ ] Test new Dockerfiles locally
- [ ] Verify all images build and test successfully
- [ ] Check that new images work with your applications

### **CI Migration**
- [ ] Backup current CI workflow
- [ ] Deploy enhanced CI workflow
- [ ] Monitor CI runs for any issues
- [ ] Verify security scanning works

### **Dockerfile Migration**
- [ ] Backup old Dockerfiles
- [ ] Replace with new Dockerfiles
- [ ] Update any hardcoded references
- [ ] Test production deployments

### **Cleanup**
- [ ] Remove old Dockerfiles (after confirming new ones work)
- [ ] Update documentation
- [ ] Archive old build scripts

## 🔧 **Troubleshooting**

### **Common Issues**

**1. Permission Issues**
```bash
# Test /app/tmp directory
docker run --rm --entrypoint="" ats-pdf-generator:alpine python3 -c "
import os
print(f'/app/tmp exists: {os.path.exists(\"/app/tmp\")}')
print(f'/app/tmp writable: {os.access(\"/app/tmp\", os.W_OK)}')
"
```

**2. Build Failures**
```bash
# Check Dockerfile syntax
docker build -f docker/Dockerfile.alpine.new -t test-alpine .

# Validate with hadolint
hadolint docker/Dockerfile.alpine.new
```

**3. Test Failures**
```bash
# Run individual tests
./scripts/test-docker-images.sh

# Debug specific image
docker run --rm ats-pdf-generator:alpine --help
```

## 📈 **Benefits After Migration**

### **For Developers**
- 🚀 **Faster Feedback** - Issues caught locally in seconds
- 🛠️ **Better Tools** - Comprehensive testing and generation scripts
- 📝 **Less Maintenance** - Automated Dockerfile generation

### **For CI/CD**
- 🔒 **Security** - Automated vulnerability scanning
- 📊 **Better Reporting** - Enhanced CI summaries
- 🧪 **Comprehensive Testing** - All Docker images tested

### **For Production**
- 🐳 **Smaller Images** - Multi-stage builds
- 🔐 **Better Security** - Non-root users and minimal dependencies
- ⚡ **Faster Builds** - Optimized Dockerfiles

## 🆘 **Rollback Plan**

If you need to rollback:

```bash
# Restore old CI workflow
cp .github/workflows/ci-legacy.yml .github/workflows/ci.yml

# Restore old Dockerfiles
cp docker/legacy/Dockerfile.* docker/

# Restore old build script
git checkout HEAD~1 scripts/build-and-test.sh
```

## 📞 **Support**

If you encounter issues during migration:

1. **Check the logs** - All scripts provide detailed output
2. **Test locally first** - Use the testing scripts before deploying
3. **Gradual migration** - Use the enhanced script that works with both old and new
4. **Rollback if needed** - Keep backups of old files

---

**Status**: ✅ **Ready for Migration** - All new tools tested and working
