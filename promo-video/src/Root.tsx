import React from 'react';
import {Composition} from 'remotion';
import {RewindPromo} from './RewindPromo';

export const Root: React.FC = () => {
  return (
    <Composition
      id="RewindPromo"
      component={RewindPromo}
      durationInFrames={900}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
