#!/bin/bash

# Script to clean up untracked content in submodules
echo "Cleaning up untracked content in submodules..."

# Function to clean a submodule
clean_submodule() {
  local submodule=$1
  echo "Cleaning up $submodule..."
  cd "lib/$submodule"
  git reset --hard HEAD
  git clean -fdx
  # Remove any nested untracked submodules
  if [ -d "lib" ]; then
    find lib -type d -name ".git" | xargs -r dirname | xargs -r -I{} sh -c "cd {} && git reset --hard HEAD && git clean -fdx"
  fi
  cd ../../
}

# Clean up specific submodules with issues
clean_submodule "chainlink"
clean_submodule "openzeppelin-contracts"

# Update all submodules recursively
echo "Updating all submodules..."
git submodule update --init --recursive --force

# Add an option to git config to ignore untracked content in submodules
echo "Setting git config to ignore untracked content in submodules..."
git config --global status.submodulesummary 0

echo "Cleaning up complete! You may need to restart your terminal session." 