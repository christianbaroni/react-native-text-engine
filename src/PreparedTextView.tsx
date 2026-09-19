import { forwardRef, type ComponentRef, type ForwardRefExoticComponent, type PropsWithoutRef, type RefAttributes } from 'react';
import textEngineAppDefaults from './generated/TextEngineAppDefaults';
import NativePreparedTextView, {
  type NativeProps as NativePreparedTextViewProps,
} from './specs/RNTextEnginePreparedTextViewNativeComponent';

/**
 * Props for the native prepared-handle render surface.
 *
 * `selectable` opts into the interaction-oriented native text owner.
 *
 * `anchorToCapHeight` aligns the view band from the first line's cap top to
 * the last visible line's baseline without trimming ascenders or descenders
 * outside that band.
 */
export type PreparedTextViewProps = NativePreparedTextViewProps & {
  ellipsizeMode?: 'clip' | 'head' | 'middle' | 'tail';
  handle?: number;
  numberOfLines?: number;
};

/**
 * Native prepared-handle render surface.
 */
export const PreparedTextView: ForwardRefExoticComponent<
  PropsWithoutRef<PreparedTextViewProps> & RefAttributes<ComponentRef<typeof NativePreparedTextView>>
> = forwardRef<ComponentRef<typeof NativePreparedTextView>, PreparedTextViewProps>(function PreparedTextView(props, ref) {
  return (
    <NativePreparedTextView ref={ref} {...props} anchorToCapHeight={props.anchorToCapHeight ?? textEngineAppDefaults.anchorToCapHeight} />
  );
});
