import React from 'react'

// Import typefaces
import 'typeface-montserrat'
import 'typeface-merriweather'

import profilePic from './profile-pic.jpg'
import { rhythm } from '../utils/typography'

class Bio extends React.Component {
  render() {
    return (
      <div
        style={{
          display: 'flex',
          marginBottom: rhythm(2.5),
        }}
      >
        <img
          src={profilePic}
          alt={`Greg Weber`}
          style={{
            marginRight: rhythm(1 / 2),
            marginBottom: 0,
            height: rhythm(2),
          }}
        />
        <p>
          Written by <strong>Greg Weber</strong> who lives and works in Silicon Valley
          building useful things.{' '}
        </p>
      </div>
    )
  }
}

export default Bio
